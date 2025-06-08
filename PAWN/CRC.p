/* CRC  functions
 * v1.0
 * (c) Copyright 2020, GLONASSsoft
 * This file is provided as is (no warranties).
 */
#pragma library Crc

stock DS_crc8_byte(data, crc)
{
  new i = data ^ crc;
  crc = 0;
  if(i & 0x01) crc ^= 0x5e;
  if(i & 0x02) crc ^= 0xbc;
  if(i & 0x04) crc ^= 0x61;
  if(i & 0x08) crc ^= 0xc2;
  if(i & 0x10) crc ^= 0x9d;
  if(i & 0x20) crc ^= 0x23;
  if(i & 0x40) crc ^= 0x46;
  if(i & 0x80) crc ^= 0x8c;
  return crc;
}

/* Посчитать контрольную сумму CRC8 */
stock calc_crc8(const data[], length)
{
  new crc8val = 0;
  for (new i = 0; i < length; i++) {
    crc8val = DS_crc8_byte(data[i], crc8val);
  }
  return crc8val;
}

/* Проверить контрольную сумму пакета */
stock bool: check_crc8(const data[], length)
  return calc_crc8(data, length) == 0


