/*
Скрипт реализует поведение охранного маяка 
Маяк может находиться в двух состояниях SERVICE включается коммандой setsvcmode=1 / PROTECTION включается коммандой setsvcmode=0
  SERVICE - маяк находится в режиме STANDBY, доступен для конфигурирования применим для хранения и транспортировки АКБ
  PROTECTION - маяк находится в режиме IDLE\RUN, выполняет охранные функции
В режиме protection маяк может переключаться между состояниями NORMAL-QUAKE-ALARM (НОРМАЛЬНОЕ - ТРЕВОГА УДАР/НАКЛОН - ТРЕВОГА ПЕРИМЕТР)

комманды конфигурирования настроек пользователем:
SetSvcMODE= 0/1 
SetSensLVL= 30-300  настройка уровня чувствительности для перехода в состояние СОБЫТИЕ
SetRestTIO= 1-30    (минут) таймаут для перехода из состояния СОБЫТИЕ в НОРМАЛЬНОЕ
SetSendInt= 5-10080 (минут) интервал между выходами в режим RUN для передачи данных в НОРМАЛЬНОМ состоянии
SetSendWnd= 1-10    (минут) длительность нахождения в режиме RUN в нормальном состоянии
*/

#include <time>
#include <float>
#include <string>
#include tracker
#include sgfence

/* Структура хранения данных */
#define ALARM_TAG           0 // тревога     1-вынос за периметр
#define QUAKE_TAG           1 // сотрясения  1-превышен допустимый порог и частота
#define STATE_TAG           2 // состояние   0-service 1-normal 2-quakes 3-alarm

/* Прочие константы */
#define CNT_TRIGGER         3           // количество полследовательных событий превышения уровня вибрации до формирования тревоги
#define VERSION             "1.0.1"     // версия скрипта
#define PERIOD              5000        // интервалы вызова state машины 5 секунд

/* Таймауты настраиваемые пользователем */ 
new lRestPeriodMin = 2; // таймаут 1-30(минут) до возврата в состояние NORMAL из QUAKE
new lSendPeriodMin = 30;// интервал 5-10080(минут) перехода в режим RUN из IDLE - для состояния NORMAL
new lSendWindowMin = 2; // время (1-10) минут на выгрузку данных ЧЯ - для состояния NORMAL 

/* Таймеры обратного отсчёта для переключения состояний*/
new DnCntSendP = 0; 
new DnCntSendW = 0; 
new DnCntRest = 0;

/* Флаги контроля состояний */
new lSvcMode = 0;   /* сервисный режим */
new lState = 0;     /* состояние */
new lQuake = 0;     /* частая вибрация */
new lAlarm = 0;     /* пересечение периметра */

/* Переменные для контроля пересечения периметра */
new homeposition[GEOFENCE_S] //для переменной используются только 3 параметра .lat .lon .r
new Lattitude;
new Longitude;

/* Переменные для работы с акслерометром */
new X0, Y0, Z0 ;        // Real Time Filtered Accelerometer Values
new DX, DY, DZ ;        // Delta/Timer Accelerometer Values
new AX, AY, AZ ;        // Last Accelerometer Values
new SENS = 30;          // пороговый уровень вибрации для создания события превышения - настраивается коммандой setsenslvl=30
new CntQuake = 0;       // количество событий превышения уровня вибрации 
new cntColdStart = 8;   // отбрасывает первые N невалидных значений фильтра акселерометра во избежание ложной тревоги

main()
{  
  lSvcMode = geteep(0);                    //читаем режим устройства 0:PROTECTION 1:SERVICE
  printf("SERVICE MODE = %d", lSvcMode);   //Отладка: выбранный режим  
  
  sgfCreateGeofence(homeposition, 45.0, 38.0, 50.0) //РАДИУС поправить на 50 метров перед сдачей скрипта
  
  settag(ALARM_TAG, lAlarm, false); // 1: вынос за периметр, передача параметра на сервер 1 или 0 - не важно, вызывает сообщение диспетчеру/вспллывающее уведомеление 
  settag(QUAKE_TAG, lQuake, false); // 1: обнаружена сильная вибрация/наклон/удар 
  settag(STATE_TAG, lState, true);  // 0-3: состояние устройства / state машины ВСЕГДА записывается в ЧЯ
  
  settimer (PERIOD,false); //настройка таймера ( false - continuous / true - single shot )
  state service_mode;
  
  // SENS уровень вибрации, превышение которого может быть вызвано внешним механическим воздействием
  // опытным путём установелно что нормальный уровень шума/вибрации не превышает отметку в 15 ед.
  // следовательно любое внешние воздействие приведёт к всплескам уровня шума минимум в два раза
  // рекомендуемый минимальный исключающий ложные тревоги не менее 30 единиц.  
    
  SENS = geteep(1); // читаем SENS из eeprom
  if (SENS > 300)   // если параметр невалидный (первый запуск)
  {SENS = 30;}
  if (SENS < 30)
  {SENS = 30;}
  seteep(1, SENS);  
  printf("SENS LEVEL = %d", SENS);      //Отладка: пороговый уровень вибрации
  
  lRestPeriodMin = geteep(2); // таймаут 1-30(минут) до возврата в состояние NORMAL из QUAKE  
  if (lRestPeriodMin > 30)
  {lRestPeriodMin = 2;}       // значение по умолчанию 2 минуты
  if (lRestPeriodMin < 1)
  {lRestPeriodMin = 2;}
  seteep(2,lRestPeriodMin);  
  printf("REST PERIOD = %d minutes", lRestPeriodMin);      //Отладка
  
  lSendPeriodMin = geteep(3); // интервал 5-10080(минут) перехода в режим RUN из IDLE - для состояния NORMAL 
  if (lSendPeriodMin < 5)
  {lSendPeriodMin = 30;}      // значение по умолчанию 30 минут
  if (lSendPeriodMin > 10080)
  {lSendPeriodMin = 30;}
  seteep(3,lSendPeriodMin);
  printf("SEND PERIOD = %d minutes", lSendPeriodMin);      //Отладка
  
  lSendWindowMin = geteep(4); // время (1-10) минут на выгрузку данных ЧЯ - для состояния NORMAL 
  if (lSendWindowMin < 1)
  {lSendWindowMin = 2;}       // значение по умолчанию 2 минуты
  if (lSendWindowMin > 10)
  {lSendWindowMin = 2;}
  seteep(4,lSendWindowMin);  
  printf("SEND WINDOW = %d minutes", lSendWindowMin); //Отладка
  
  Lattitude = geteep(5);
  Longitude = geteep(6);
  printf("HOME LATTITUDE = %d", Lattitude); 
  printf("HOME LONGITUDE = %d", Longitude); 
  homeposition.lat = float(Lattitude)/1000000;
  homeposition.lon = float(Longitude)/1000000;      
}

@accupdate()
{
  new acc[.x, .y, .z] ;
  new dX, dY, dZ ; // temporary Delta values
  new Delta = 0 ; 
  
  getacc(acc) ;
  dX = acc.x - X0 ;
  dY = acc.y - Y0 ;
  dZ = acc.z - Z0 ;
  X0 = X0 + dX / 2 ;
  Y0 = Y0 + dY / 2 ;
  Z0 = Z0 + dZ / 2 ;
  //printf("X %d Y %d Z %d", X0, Y0, Z0); // Отладка

  // === == QUAKE Detector BEGIN == ===
  //вычислиям абсолютные отклонения
  if (X0 > AX)
  { DX = X0 - AX ; }
  else
  { DX = AX - X0 ; }
  AX = X0 ;

  if (Y0 > AY)
  { DY = Y0 - AY ; }
  else
  { DY = AY - Y0 ; }
  AY = Y0 ;

  if (Z0 > AZ)
  { DZ = Z0 - AZ ; }
  else
  { DZ = AZ - Z0; }
  AZ = Z0 ;
  
  //суммируем отклонения
  Delta = DX + DY + DZ ;
  
  //printf("dX %d dY %d dZ %d Summ %d", DX, DY, DZ, Delta); // Отладка
  
  if (Delta >= SENS) // если уровень вибрации выше порога
    CntQuake++;      // увеличиваем значение счётчика   
  else if (CntQuake > 0)
    CntQuake--;      // уменьшаем счётчик до 0, но не в минус.
  
  if (cntColdStart > 0) 
  {
    cntColdStart--;  // пока данные фильтра после запуска скрипта не стабилизировались
    if(CntQuake > 0)
      CntQuake--;    // отбрасываем ложные тревоги
  }   
  //printf("DELTA= %d QUAKE= %d COLDCOUNTER= %d", Delta, UpUpUpCntQuake, cntColdStart); // Отладка
  
  if (CntQuake >= CNT_TRIGGER) // тревога по количеству событий вибрации
  {
    if (lQuake !=1)
      printf("ALARM Too many quakes ");  // Отладка 
    lQuake = 1; // данную переменную можно обрабатывать только режиме normal_mode    
  }     
  // ^^^ ^^ QUAKE Detector END ^^ ^^^  
}


@gnssupdate()
{  
  new position[Float: .lat, Float: .lon, Float: .height, Float: .course, Float: .speed, Float: .hdop];

  // printf("Protect Mode Active")
  if (getposition(position))
  {    
    if (sgfCheckInsideGeofence(homeposition, position.lat, position.lon))
    {      
      if (lAlarm ==1)
      {
        lAlarm=0; //переменная может обнулиться но это не переключит состояние устройства
        printf("Terminal resume to geofence");
      }      
    }
      
    else if (lAlarm == 0)
    { //при первом событии выхода за периметр выведем уведомление и включим флаг тревоги
      lAlarm=1; //переменная обрабатывается в quake состоянии
      printf("Terminal left the geofence");
    }     
  }  
}

/* = = = БЛОК ОСНОВНЫХ СОСТОЯНИЙ УСТРОЙСТВА = = = */

@timer() <service_mode> // РЕАЛИЗУЕТСЯ В РЕЖИМЕ СТАТИЧЕСКОЙ НАВИГАЦИИ (НА СТОЯНКЕ)
{
  if (lState!=0)
  {
    printf("Entering SERVICE state processor"); // Отладка
    lState = 0;                        // указываем в переменную номер состояния системы
    settag(STATE_TAG, lState, true);   // записываем переменную для передачи в ЧЯ      
  }  
  setpwrstate(pwr_state: PWR_STATE_STANDBY); // удерживаем режим питания в STDBY
  
  // переходы в другие состояния  
  if (lSvcMode == 0)                     
  {state normal_mode;}
}

@timer() <normal_mode> // РЕАЛИЗУЕТСЯ В РЕЖИМЕ СТАТИЧЕСКОЙ НАВИГАЦИИ (НА СТОЯНКЕ)
{   /* интервал передачи координат (настраивается) параметром режима "на стоянке" */    
  if (lState !=1)
  {
    printf("Entering NORMAL state processor");
    lState = 1;
    settag(STATE_TAG, lState, true);
    //setpwrstate(pwr_state: PWR_STATE_IDLE); // смена режима питания
    //printf("Power Mode Set to IDLE");
  }   
  
  if (DnCntSendP > 0)
    DnCntSendP--;   // обратный отсчёт  
  else              // при первом попадании в этот процессор состояния мы взводим таймер периода передачи и таймер окна передачи.
  {                 // запускаем режим RUN и передаём данные
    DnCntSendP = lSendPeriodMin * 12        //взводим таймер периода передачи
    if (DnCntSendW == 0)                    //проверяем таймер окна передачи
    {
      DnCntSendW = lSendWindowMin * 12;     //взводим таймер окна передачи
      DnCntSendW ++; 
      setpwrstate(pwr_state: PWR_STATE_RUN);//выходим на связь
      printf("Power Mode Set to RUN");
    }    
  }
  printf("Countdown Send Period: %d seconds", DnCntSendP*5 );    //Отладка
    
  if (DnCntSendW > 0)//отсчитываем таймер окна передачи
  {     
    DnCntSendW--;    
    printf("Countdown Send Window: %d seconds", DnCntSendW*5 ); //Отладка
    if (DnCntSendW ==0)
    { 
      setpwrstate(pwr_state: PWR_STATE_IDLE); //по окончании окна передачи, переключаемся в режим IDLE
      printf("Power Mode Set to IDLE");
    }    
  }  
  
  // переходы в другие состояния  
  if (lQuake == 1)
  {state quake_mode;}     //переход в сотсояние quakes !!! при этом настройки устройства должны обеспечить переход в режим "в движении"
  
  if (lSvcMode == 1)      //переключение в сервсиный режим доступно только из нормального состояния
  {state service_mode;}
}

@timer() <quake_mode>  /* передача координат каждые 30 секунд (настраивается) */
{    /* через 5 минут надо вывалиться из этого режима обратно (настраивается) */    
  if (lState != 2)
  {
    printf("Entering QUAKE state processor"); // Отладка
    lState = 2;
    settag(STATE_TAG, lState, true);
    setpwrstate(pwr_state: PWR_STATE_RUN);
    printf("Power Mode Set to RUN");    
    settag(QUAKE_TAG, lQuake, true); //подготовим валидное событие для записи в ЧЯ    
    pushpoint(true);                 //запишем приоритетную точку для отпавки на сервер
  }  
  
  if (lQuake == 1)
  {
    settag(QUAKE_TAG, lQuake, true);
    lQuake = 0;                      //сбросим флаг после обработки
    DnCntRest = lRestPeriodMin * 12; //1 минута = 12 вызовов таймера с периодом выполнения 5 секунд
  }                                  // обратный отсчёт сбрасыватеся при любом повторном сострясении прибора и начинается заново
  else
  {
    settag(QUAKE_TAG, lQuake, true); //подготовим валидное событие для записи в ЧЯ 
  } //возможно придётся установить флаг false из-за особенностей нашего сервера, иначе он заспамит "0"-уведомлениями оператора
  
  if(DnCntRest > 0 )
  {
    DnCntRest--;
    printf("Countdown Rest Time: %d seconds", DnCntRest*5 );      //Отладка
  }
  else                                
  {                                   // по окончании отсчёта 
    settag(QUAKE_TAG, lQuake, false); // убираем флаг валидности для параметра
    state normal_mode;                // переключаемся в нормальный режим
    printf("everything is quiet, resuming to normal state ");      //Отладка
    setpwrstate(pwr_state: PWR_STATE_IDLE); // смена режима питания
    printf("Power Mode Set to IDLE");
  }                                   // вроде больше ничего не забыли  
  
  if (lAlarm == 1)
  {
    state alarm_mode;    
  }
  // 
}

@timer() <alarm_mode>
{
  if (lState !=3)
  {
    printf("Entering ALARM state processor");
    lState = 3;
    settag(STATE_TAG, lState, true);  
    settag(ALARM_TAG, lAlarm, true);
    setpwrstate(pwr_state: PWR_STATE_RUN);    
  }    
  //выход из этого состояния возможен только по внешней комманде RESET   
  //либо по менеджеру питания при разряде АКБ
}


@chat(string{128})
{  
  if (strequal(string, "STATUS",true))
  { 
    strformat(string, sizeof(string), true, "State:%d, Quake:%d, Alarm:%d, ver:%s", lState, lQuake, lAlarm, VERSION );
  }  
  
  else if (strequal(string, "Settings",true))
  { 
    strformat(string, sizeof(string), true, "Sens: %d, RestTimeOut: %dm, SendInterval: %dm, SendWindow: %dm", SENS, lRestPeriodMin, lSendPeriodMin, lSendWindowMin);
  }   
  
  else if (strequal(string, "RESET",true)) //сброс тревоги и возврат в состояние NORMAL
  {    
    lAlarm = 0; // сброс тревожных флагов
    lQuake = 0;    
    
    strcopy(string, "event reset") // отвечаем пользователю
    settag(ALARM_TAG, lAlarm, false);
    settag(QUAKE_TAG, lQuake, false); 
    
    DnCntSendP = 0; 
    DnCntSendW = 0;
    
    state normal_mode;                // переключение в состояние NORMAL    
  }
  
  else if (strequal(string, "SetHome",true)) //установка охранного периметра
  {     
    new position[Float: .lat, Float: .lon, Float: .height, Float: .course, Float: .speed, Float: .hdop];    
  
    if (lState ==3)
    {
      strcopy(string, "System in ALARM state, changing the geofence is prohibited");
    }
    else if (getposition(position)) // Получаем текущие координаты
    {
      strcopy(string, "Valid GNSS data recieved, geofence is set");
      homeposition.lat = position.lat;
      homeposition.lon = position.lon;
      
      Lattitude = floatround(position.lat * 1000000);
      Longitude = floatround(position.lon * 1000000);
      printf("HOME LATTITUDE = %d", Lattitude);
      printf("HOME LONGITUDE = %d", Longitude);
      seteep(5,Lattitude);
      seteep(6,Longitude);        
    }
    else
    {
      strcopy(string, "No valid GNSS data"); //printf("No valid GPS Data");      
    }    
  }  
  
  /* обработка комманды переключения режима SERVICE lSvcMode=1 / PROTECTION lSvcMode=0 */
  else if (strequal(string, "SetSvcMODE", true, 10)) //пример комманды >> chat SetSvcMODE=1
  {
    new DataLen=0;
    new NewValue = 0;
    DataLen = strlen(string)
    if (DataLen == 12)      //проверка на полноту строки
    {
      NewValue = strval(string, 12);    
      if (NewValue > 1)     //проверка на корректность числового параметра
      {                     //значение некорректно
        strformat(string, sizeof(string), true, "%d Is Invalid Value", NewValue);
      }
      else
      {
        lSvcMode = NewValue;   //принимаем новое значение из комманды
        strformat(string, sizeof(string), true, "ServiceMode = %d", lSvcMode);
        seteep(0,lSvcMode);    //записываем настройку в память
      }
    }
    else                    //отсутсвует параметр
      strcopy(string, "paramater missed '=?' ")
  }
  
  /* обработка комманды настройки порога вибрации для формирования тревоги */
  else if (strequal(string, "SetSensLVL", true, 10)) //пример комманды >> chat SetSensLVL=30
  {
    new DataLen=0;
    new NewValue = 0;
    DataLen = strlen(string)
    if (DataLen >= 12)      //проверка на полноту
    {
      NewValue = strval(string, 11);    
      if (NewValue > 300)   //проверка на корректность числового параметра
      { strformat(string, sizeof(string), true, "%d Is Too Much, max value is 300", NewValue); }
      else if (NewValue < 30)
      { strformat(string, sizeof(string), true, "%d Is Too Low, min value is 30", NewValue); }      
      else
      {
        SENS = NewValue;   //принимаем новое значение из комманды
        strformat(string, sizeof(string), true, "SensLVL = %d", SENS);    
        seteep(1, SENS);   //записываем настройку в память
      }      
      printf("SensLVL = %d", SENS);     // отладка      
    }
    else                    //отсутсвует параметр
      strcopy(string, "paramater missed '=?' ")
  }  
  
  /* обработка комманды настройки таймаута режима СОБЫТИЕ */
  else if (strequal(string, "SetRestTIO", true, 10)) //пример комманды >> chat SetRestTIO=1
  {
    new DataLen=0;
    new NewValue = 0;
    DataLen = strlen(string)
    if (DataLen >= 12)      //проверка на полноту
    {
      NewValue = strval(string, 11);    
      if (NewValue > 30)   //проверка на корректность числового параметра
      { strformat(string, sizeof(string), true, "%d Is Too Much, max value is 30", NewValue); }
      else if (NewValue < 1)
      { strformat(string, sizeof(string), true, "%d Is Too Low, min value is 1", NewValue); }      
      else
      {
        lRestPeriodMin = NewValue;   //принимаем новое значение из комманды
        strformat(string, sizeof(string), true, "RestTimeOut = %d", lRestPeriodMin);    
        seteep(2,lRestPeriodMin);    //записываем настройку в память        
        DnCntRest = lRestPeriodMin * 12; //обновляем счётчик
      }      
      printf("RestTimeOut = %d", lRestPeriodMin);     // отладка      
    }
    else                    //отсутсвует параметр
      strcopy(string, "paramater missed '=?' ")
  }
  
  /* обработка комманды настройки интервала передачи данных */
  else if (strequal(string, "SetSendInt", true, 10)) //пример комманды >> chat SetSendInt=5
  {
    new DataLen=0;
    new NewValue = 0;
    DataLen = strlen(string)
    if (DataLen >= 12)      //проверка на полноту
    {
      NewValue = strval(string, 11);    
      if (NewValue > 10080)   //проверка на корректность числового параметра
      { strformat(string, sizeof(string), true, "%d Is Too Much, max value is 10080", NewValue); }
      else if (NewValue < 5)
      { strformat(string, sizeof(string), true, "%d Is Too Low, min value is 5", NewValue); }      
      else
      {
        lSendPeriodMin = NewValue;   // принимаем новое значение из комманды
        strformat(string, sizeof(string), true, "Send Interval is %d minutes", lSendPeriodMin);    
        seteep(3,lSendPeriodMin);    // записываем настройку в память
        DnCntSendW = 0;              // инициализируем счётчики
        DnCntSendP = 0;              // инициализируем счётчики        
      }      
      printf("SendInterval = %d", lSendPeriodMin);     // отладка      
    }
    else                    //отсутсвует параметр
      strcopy(string, "paramater missed '=?' ")
  }
  
  /* обработка комманды настройки длительности окна передачи данных */
  else if (strequal(string, "SetSendWnd", true, 10)) //пример комманды >> chat SetSendWnd=2
  {
    new DataLen=0;
    new NewValue = 0;
    DataLen = strlen(string)
    if (DataLen >= 12)      //проверка на полноту
    {
      NewValue = strval(string, 11);    
      if (NewValue > 10)   //проверка на корректность числового параметра
      { strformat(string, sizeof(string), true, "%d Is Too Much, max value is 10", NewValue); }
      else if (NewValue < 1)
      { strformat(string, sizeof(string), true, "%d Is Too Low, min value is 1", NewValue); }      
      else
      {
        lSendWindowMin = NewValue;   //принимаем новое значение из комманды
        strformat(string, sizeof(string), true, "Send Window is %d minutes", lSendWindowMin);    
        seteep(4,lSendWindowMin);    //записываем настройку в память
        DnCntSendW = 0;              // инициализируем счётчики
        DnCntSendP = 0;              // инициализируем счётчики        
      }      
      printf("SendWindow = %d", lSendWindowMin);     // отладка      
    }
    else                    //отсутсвует параметр
      strcopy(string, "paramater missed '=?' ")
  }  
  
  /*  разные отладочные команды    */  
  
  /* переключение режимов питания  (Power Mode) сокр. (pm) */
  else if (strequal(string, "pmRUN"))
  {    
    strcopy(string, "Power Mode RUN")
    setpwrstate(pwr_state: PWR_STATE_RUN)
  } 
  else if (strequal(string, "pmIDLE"))
  {    
    strcopy(string, "Power Mode IDLE")
    setpwrstate(pwr_state: PWR_STATE_IDLE)
  } 
  else if (strequal(string, "pmSLEEP"))
  {    
    strcopy(string, "Power Mode SLEEP")
    setpwrstate(pwr_state: PWR_STATE_STANDBY)
  } 
  else 
  {
    strformat(string, sizeof(string), true, "Command not found");
  }
  
}

