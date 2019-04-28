# nesasm
Assembler for NES 6502 assembly, version 3.1 (latest as of March 2016) with some additional improvements/modifications.

### Usage
```bash
cd source && make
sudo make install (optional)
```

Then run the assembler with `nesasm`.  Please see [`usage.txt`](https://raw.githubusercontent.com/bunder2015/nesasm/master/usage.txt) for more details.

### License
The original license is as follows: (Can also be found in main.c)

`This program is freeware. You are free to distribute, use and modify it as you wish.`

### Credits
* Original 6502 version by: J. H. Van Ornum
* PC-Engine version by: David Michel, Dave Shadoff
* NES version by: Charles Doty
* Original 3.1 source, by [bunnyboy](http://nintendoage.com/index.cfm?FuseAction=Users.Home&User=bunnyboy), is [available here](http://www.nespowerpak.com/nesasm/nesasmsrc.zip).
* Improvements/modifications by:
	* @camsaul - Linux Makefile ([b151f0c](https://github.com/camsaul/nesasm/commit/b151f0c7cbfaa63690c8a72fdf59c75551878be6))
	* @kevinselwyn - Bug fixes ([5304ab5](https://github.com/kevinselwyn/nesasm/commit/5304ab54b211720f88872911a01827d8bbdef3d5))
	* @munshkr - Removal of unnecessary PC-Engine code ([ecc637d](https://github.com/munshkr/nesasm/commit/ecc637dc139b61cfd62d61cbb1aef0207d22f8db)) ([cc5c6a2](https://github.com/munshkr/nesasm/commit/cc5c6a25d0002ff51ea1d133633c4bf8325dcae4))

Please see [`changelog.txt`](https://raw.githubusercontent.com/bunder2015/nesasm/master/changelog.txt) for changelog data prior to github.

Please note: this may not be the complete list of contributors, if your name is not on this list, I apologize.  Finding the full revision/contributor history for 20+ year old software is quite difficult.  Please file a bug for appropriate attribution.
