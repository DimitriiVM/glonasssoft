/*
Пример работы с числами с плавающей точкой
и записью параметров в ЧЯ
*/

#include <tracker>
#include <float>

#pragma dynamic 128

main()
{
    new Float: Sin; // Значение синуса
    new Float:Degrees = 0.0; // Градус
    new TagValue;
    new Step = 0
    
    for(;;)
    {
        Sin = floatsin(Degrees, degrees); // Вычисляем синус
        printf("Sin(%.01f) = %.03f", Step, Degrees, Sin); // Выводим
        settag(0, Step, true, 0); // В ячейку 0 пишем значение шага
        /* Значение градуса выводим с точностью до десятых*/
        TagValue = floatround((Degrees * 10), floatround_floor); 
        settag(1, TagValue, true, 1); // В ячейку 1 пишем значение градуса
        /* Значение синуса выводим с точностью до тысячных */
        TagValue = floatround((Sin * 1000), floatround_floor);
        settag(2, TagValue, true, 3); // В ячейку 2 пишем значение синуса        
        if ((Step % 100) == 0) pushpoint(); // Сохраняем в истории каждые 100 шагов
        Degrees += 0.1; // Увеличиваем на 0,1 градус
        Step++; // Увеличиваем номер шага            
        sleep(100);
    } 
}