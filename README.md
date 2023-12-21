# PP1Unpacker

This is a small program which uncompresses PP1 files used in Super Robin Hood game. Results are compatible with NES PPU format described [here](https://www.nesdev.org/wiki/PPU_pattern_tables).

## How to run?

You need Commander X16 to be able to run this program. I tested it only on emulator. You also need [cx16shell](https://github.com/irmen/cx16shell) as this program is written as command for this shell.

Ready to use setup is placed in `sdcard` directory on this repository. Copy your PP1 files into sdcard directory, run emulator. Execute `pp1unpack FILENAME.PP1`. `FILENAME.PP1.CHR` result will be produced.

## Considerations

Program loads PP1 files into $6000 in main memory. Uncompressed data is getting stored in $7000 in main memory. So effectively you have $1000 bytes for compressed PP1 files and $2EFF for uncompressed data.

## License

I'm licensing this code as Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported because original assembly code for unpacking pp1 files is licensed with this license. You can find original code here: https://github.com/Wireframe-Magazine/Wireframe-34/tree/master
