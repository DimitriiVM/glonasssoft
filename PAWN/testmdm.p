#include <console>
#include <string>
#include tracker
#include modem

#pragma dynamic 128

@loop()
{
    new number{17}
    
    if (iscalling())
        printf "calling!"
    
    if (getcallerid(number))
        printf("number \"%s\"", number)
    
#if 1
    /* Отбой вызова */
    if (iscalling())
    {
        dohang()
        printf "hang!"
    }
#endif    
    
#if 0
    /* Поднять трубку */
    if (iscalling())
    {
        doanswer()
        printf "answer!"
    }
#endif    
}

@callerid(const number{})
{
#if 1    
    /* Отправить СМС с номером в обратную сторону */
    new smstext{141}
    
    strformat(smstext, _, _, "You number: \"%s\"", number)
    sendsmsnum(smstext, number)
#endif        
    
    printf("event number \"%s\"", number)    
}