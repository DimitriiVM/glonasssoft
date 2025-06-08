/* Modbus functions
 * v0.1
 * (c) Copyright 2020, GLONASSsoft
 * This file is provided as is (no warranties).
 */
#pragma library Modbus

/* Посчитать контрольную сумму CRC16 */
stock mdbrtu_crc(const data[], length)
{
  new reg_crc = 0xFFFF

  for (new i = 0; i < length; i++)
  {
    reg_crc ^= data[i]
    for (new j = 0; j < 8; j++)
    {
      reg_crc &= 0xFFFF

      if (reg_crc & 1)
        reg_crc = (reg_crc >> 1) ^ 0xA001 // LSB(b0) = 1
      else
        reg_crc = reg_crc >> 1
    }
  }
  return reg_crc & 0xFFFF
}

/* Проверить контрольную сумму пакета */
stock bool: mdbrtu_crc_check(const data[], length)
  return mdbrtu_crc(data, length) == 0

