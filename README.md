## Kanji reading practice sheets

### Requirements

Debian, Ubuntu: apt-get install libdbd-sqlite3-perl

Arch: pacman -S perl-dbd-sqlite

### How to

First generate dictionary using my generate_kanji_dictionary, then enter characters you want to practice into my_kanji.txt (one per line), fill in what characters you already know (not needed) into i_know_kanji.txt and execute script:

```
perl generate_kanji_sheet.pl > practice.html
```

### Usage

By default script prints 12 words with each kanji, radicas and suggested characters are hidden.

```
-w <number> :how many words should be printed with character
-r :print radicals
-s :print suggested kanji\n";
```

### How it works

First it collets all kanji from database into hash. Next, usekanji table is filled with characters from @mykanji and @iknowkanji. usekanji only purpose is to count how many of those characters appear in each word. After that each character from @mykanji is printed inside template with example words and radicals. Example words are choosen based on how many of selected characters are inside them and lenght of the word. 

Radicals printed below character are separated into two types:

1. Radicals
2. Parts

Each character has (AFAIK) only one base radical, but you can also identify it by parts (see http://jisho.org/search/%E6%A0%A1%20%23kanji).

There are three switches that control how the result looks like:

1. -w <number> - how many example words print with each character (default: 12).
2. -r - show radicals under characters.
3. -s - count kanji that appear in words (excluding @mykanji and @iknokanji) and print them into STDERR.

### Why ?

I think the best method of learning kanji it to try reading something. When I tried that with books and articles I (obviously) couldn't control what characters are going to appear in them, usually finding only two or three which I knew. So I figured the only thing I can do is get dictionary and choose words that use kanji that I know, write down rest of them, find their meaning, add them to list, find words using new list, and so on.

Template is based on "print" option from Tagainijisho.

