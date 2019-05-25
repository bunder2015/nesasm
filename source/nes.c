#include <stdio.h>
#include <string.h>
#include "defs.h"
#include "externs.h"
#include "protos.h"
#include "nes.h"

/* locals */
static int ines_prg;		/* number of prg banks */
static int ines_chr;		/* number of character banks */
static int ines_byte6;
static int ines_byte7;
static int ines_byte8;
static int ines_byte9;
static int ines_byte10;

static struct INES {		/* INES rom header */
	unsigned char id[4];	// 0-3
	unsigned char prg;	// 4
	unsigned char chr;	// 5
	unsigned char byte6;	// 6
	unsigned char byte7;	// 7
	unsigned char byte8;	// 8
	unsigned char byte9;	// 9
	unsigned char byte10;	// 10
	unsigned char unused[5]; // 11-15
} header;


/* ----
 * write_header()
 * ----
 * generate and write rom header
 */

void
nes_write_header(FILE *f, int banks)
{
	/* setup INES header */
	memset(&header, 0, sizeof(header));
	header.id[0] = 'N';	// 0
	header.id[1] = 'E';	// 1
	header.id[2] = 'S';	// 2
	header.id[3] = 0x1A; 	// 3
	header.prg = ines_prg;	// 4
	header.chr = ines_chr;	// 5
	header.byte6 = ines_byte6; // 6
	header.byte7 = ines_byte7; // 7
	header.byte8 = ines_byte8; // 8
	header.byte9 = ines_byte9; // 9
	header.byte10 = ines_byte10; // 10

	/* write */
	fwrite(&header, sizeof(header), 1, f);

	(void)(banks);
}


/* ----
 * pack_8x8_tile()
 * ----
 * encode a 8x8 tile for the NES
 */

int
nes_pack_8x8_tile(unsigned char *buffer, void *data, int line_offset, int format)
{
	int i, j;
	int cnt, err;
	unsigned int   pixel;
	unsigned char *ptr;
	unsigned int  *packed;

	/* pack the tile only in the last pass */
	if (pass != LAST_PASS)
		return (16);

	/* clear buffer */
	memset(buffer, 0, 16);

	/* encode the tile */
	switch (format) {
	case CHUNKY_TILE:
		/* 8-bit chunky format */
		cnt = 0;
		ptr = data;

		for (i = 0; i < 8; i++) {
			for (j = 0; j < 8; j++) {
				pixel = ptr[j ^ 0x07];
				buffer[cnt]   |= (pixel & 0x01) ? (1 << j) : 0;
				buffer[cnt+8] |= (pixel & 0x02) ? (1 << j) : 0;
			}
			ptr += line_offset;
			cnt += 1;
		}
		break;

	case PACKED_TILE:
		/* 4-bit packed format */
		cnt = 0;
		err = 0;
		packed = data;

		for (i = 0; i < 8; i++) {
			pixel = packed[i];

			for (j = 0; j < 8; j++) {
				/* check for errors */
				if (pixel & 0x0C)
					err++;

				/* convert the tile */
				buffer[cnt]   |= (pixel & 0x01) ? (1 << j) : 0;
				buffer[cnt+8] |= (pixel & 0x02) ? (1 << j) : 0;
				pixel >>= 4;
			}
			cnt += 1;
		}

		/* error message */
		if (err)
			error("Incorrect pixel color index!");
		break;

	default:
		/* other formats not supported */
		error("Internal error: unsupported format passed to 'pack_8x8_tile'!");
		break;
	}

	/* ok */
	return (16);
}


/* ----
 * do_defchr()
 * ----
 * .defchr pseudo
 */

void
nes_defchr(int *ip)
{
	unsigned char buffer[16];
	unsigned int data[8];
	int size;
	int i;

	/* define label */
	labldef(loccnt, 1);

	/* output infos */
	data_loccnt = loccnt;
	data_size   = 3;
	data_level  = 3;

	/* get tile data */
	for (i = 0; i < 8; i++) {
		/* get value */
		if (!evaluate(ip, (i < 7) ? ',' : ';'))
			return;

		/* store value */
		data[i] = value;
	}

	/* encode tile */
	size = nes_pack_8x8_tile(buffer, data, 0, PACKED_TILE);

	/* store tile */
	putbuffer(buffer, size);

	/* output line */
	if (pass == LAST_PASS)
		println();
}


/* ----
 * do_inesprg()
 * ----
 * .inesprg pseudo
 */

void
nes_inesprg(int *ip)
{
	if (!evaluate(ip, ';'))
		return;

	if (value == 0)
	{
		error("PRG ROM bank value cannot be zero! (1-64)");
		return;
	}

	// TODO: Should this be a power of two?
	if (value > 64)
	{
		error("PRG ROM bank value out of range! (1-64)");
		return;
	}

	// Set PRG ROM size
	ines_prg = value;

	if (pass == LAST_PASS)
	{
		println();
	}
}


/* ----
 * do_ineschr()
 * ----
 * .ineschr pseudo
 */

void
nes_ineschr(int *ip)
{
	if (!evaluate(ip, ';'))
		return;

	// TODO: Should this be a power of two?
	if (value > 64)
	{
		error("CHR ROM bank value out of range! (0-64)");
		return;
	}

	// Set CHR ROM size
	ines_chr = value;

	if (pass == LAST_PASS)
	{
		println();
	}
}


/* ----
 * do_inesmap()
 * ----
 * .inesmap pseudo
 */

void
nes_inesmap(int *ip)
{
	if (!evaluate(ip, ';'))
		return;

	if (value > 255)
	{
		error("Mapper value out of range! (0-255)");
		return;
	}

	// Set low mapper nibble
	ines_byte6 &= 0x0F;
	ines_byte6 |= (value & 0x0F) << 4;

	// Set high mapper nibble
	ines_byte7 &= 0x0F;
	ines_byte7 |= (value & 0xF0) << 4;

	if (pass == LAST_PASS)
	{
		println();
	}
}


/* ----
 * do_inesmir()
 * ----
 * .ines.mirror pseudo
 */

void
nes_inesmir(int *ip)
{
	if (!evaluate(ip, ';'))
		return;

	if (value > 1)
	{
		error("Mirror value out of range! (0-1)");
		return;
	}

	if (value == 1)
	{
		// Set mirroring bit
		ines_byte6 &= 0xFE;
		ines_byte6 |= 0x01;
	}

	if (pass == LAST_PASS)
	{
		println();
	}
}

/* ----
 * do_inesbat()
 * ----
 * .ines.battery pseudo
 */

void
nes_inesbat(int *ip)
{
	if (!evaluate(ip, ';'))
		return;

	// TODO: Check for PRG RAM presence
	if (value > 1)
	{
		error("Battery value out of range! (0-1)");
		return;
	}

	if (value == 1)
	{
		// Set battery bit
		ines_byte6 &= 0xFD;
		ines_byte6 |= 0x02;
	}

	if (pass == LAST_PASS)
	{
		println();
	}
}

/* ----
 * do_inesreg()
 * ----
 * .ines.region pseudo
 */

void
nes_inesreg(int *ip)
{
	if (!evaluate(ip, ';'))
		return;

	// TODO: Dual compatible ROMs
	if (value > 1)
	{
		error("Region value out of range! (0-1)");
		return;
	}

	if (value == 1)
	{
		// Set byte 9 region
		ines_byte9 &= 0xFE;
		ines_byte9 |= 0x01;

		// Set byte 10 region
		ines_byte10 &= 0xFC;
		ines_byte10 |= 0x02;
	}

	if (pass == LAST_PASS)
	{
		println();
	}
}

/* ----
 * do_inesprs()
 * ----
 * .ines.prgramsize pseudo
 */

void
nes_inesprs(int *ip)
{
	if (!evaluate(ip, ';'))
		return;

	// TODO: Should this be a power of two?
	if (value > 8)
	{
		error("PRG RAM bank value out of range! (0-8)");
		return;
	}

	if (value > 0)
	{
		// Set PRG RAM presence
		ines_byte10 &= 0xEF;
		ines_byte10 |= 0x10;

		// Set PRG RAM size
		ines_byte8 &= 0x00;
		ines_byte8 |= value;
	}

	if (pass == LAST_PASS)
	{
		println();
	}
}

/* ----
 * do_inesbus()
 * ----
 * .ines.busconflicts pseudo
 */

void
nes_inesbus(int *ip)
{
	if (!evaluate(ip, ';'))
		return;

	if (value > 1)
	{
		error("Bus conflict value out of range! (0-1)");
		return;
	}

	if (value == 1)
	{
		// Set bus conflicts bit
		ines_byte10 &= 0xDF;
		ines_byte10 |= 0x20;
	}

	if (pass == LAST_PASS)
	{
		println();
	}
}

/* ----
 * do_inesfsm()
 * ----
 * .ines.fourscreen pseudo
 */

void
nes_inesfsm(int *ip)
{
	if (!evaluate(ip, ';'))
		return;

	if (value > 1)
	{
		error("Four-screen value out of range! (0-1)");
		return;
	}

	if (value == 1)
	{
		// Set four-screen mirroring bit
		ines_byte6 &= 0xF7;
		ines_byte6 |= 0x08;
	}

	if (pass == LAST_PASS)
	{
		println();
	}
}
