#ifndef __CRC8_H_
#define __CRC8_H_

/* Functions and types for CRC checks.
 * using the configuration:
 *  - Width         = 8
 *  - Poly          = 0x07 (z^8 + z^2 + z + 1)
 *  - XorIn         = 0x00
 *  - ReflectIn     = False
 *  - XorOut        = 0x00
 *  - ReflectOut    = False
 *  - Algorithm     = table-driven
 */

#define CRC_ALGORITHM_TABLE_DRIVEN 1 // not used

/* Calculate the initial crc value. */
static inline unsigned char crc_init(void) {
	return 0x00;
}

/* Calculate the CRC8 value with the data.
 *
 * \param[in] data     Pointer to a buffer of data_len bytes.
 * \param[in] data_len Number of bytes in the data buffer.
 * \return             The CRC8 value.
 */
unsigned char crc8(const void *data_ptr, unsigned int data_len);

/* Calculate the CRC8 value on the HEX string */
unsigned char crc8_hex(const char *hex_ptr, unsigned int hex_len);

/* Add CRC8 to the end of hes string*/
char *add_crc8_to_hexstring(char* hexCRC8, const char *hex_ptr, unsigned int hex_len);

/* Print CRC8 configuration */
void print_crc8_params(void);

/* Convert hex string to ascii string */
char *hexToAscii(char *str_ptr, unsigned int str_size, const char *hex_ptr);
/* Convert ascii string to hex string */
char *asciiToHex(char *hex_ptr, unsigned int hex_size, const char *str_ptr);
/* Convert hex string to binary string */
char *hexToBin(char *bin_ptr, unsigned int bin_size, const char *hex_ptr);
/* Convert bin string to hex string */
char *binToHex(char *hex_ptr, unsigned int hex_size, const char *bin_ptr);
/* Convert bin string to unsigned long int (=strtoul(const char *bin_ptr, NULL, 2)) */ 
unsigned long binToInt(const char *bin_ptr);
/* Convert unsigned long int to string according to the given base */
char *ulToStr(unsigned long value, char *ptr, int base);

#endif      /* __CRC8_H_ */
