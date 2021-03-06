#!/usr/bin/perl

use utf8;
use strict;
use warnings;
use DBI;
use Getopt::Std;

use open ':std', ':encoding(UTF-8)';

my $dbh = DBI->connect(          
    "dbi:SQLite:dbname=dictionary.db", 
    "",                          
    "",                          
    { RaiseError => 1, sqlite_unicode => 1, },         
) or die $DBI::errstr;

my %options;
getopts("hw:rsica", \%options);

my $words_per_character=12;
my $print_radicals=0;
my $print_suggested_kanji=0;
my $dont_attach_txt=0;

if($options{h}) {
 print "Usage:
 -c :prefer common words
 -i :prefer regular kanji usage
 -r :print radicals
 -s :print suggested kanji
 -a :don't attach i_know_kanji.txt and my_kanji.txt on top of html
 -w <number> :how many words should be printed with character\n";
 exit();
}

if($options{w}) {
 if($options{w} =~ /^\d+$/) {
  $words_per_character=$options{w};
 } else {
  print STDERR "-w switch should be used with integer\n";
  exit(1);
 }
}

if($options{r}) {
 $print_radicals=1;
}

if($options{s}) {
 $print_suggested_kanji=1;
}

my @additional_sort;

if($options{i}) {
 push(@additional_sort, 'w.irregular asc');
}

if($options{c}) {
 push(@additional_sort, 'w.common desc');
}

if($options{i} || $options{c}) {
 push(@additional_sort, '');
}

if($options{a}) {
 $dont_attach_txt=1;
}

my @mykanji;

my @iknowkanji;

my %kanji;
my $kanji_query = $dbh->prepare("select id, character, reading_on, reading_kun, meaning from kanji");
$kanji_query->execute();

while (my ($kanji_id , $kanji_character , $kanji_reading_on , $kanji_reading_kun , $kanji_meaning ) = $kanji_query->fetchrow() ) {
 $kanji{$kanji_character} = {
  'ID' => $kanji_id,
  'On' => $kanji_reading_on,
  'Kun' => $kanji_reading_kun,
  'Meaning' => $kanji_meaning,
 };
}

open my $my_kanji_file, '<:encoding(UTF-8)', 'my_kanji.txt' or die "my_kanji.txt not found\n";

print "<!-- my_kanji.txt\n" unless $dont_attach_txt;

while (<$my_kanji_file>){
 print unless $dont_attach_txt;
 chomp;
 next if /^#/;
 next if /^$/;
 if ( $kanji{$_} ) {
  push(@mykanji, $_);
 }
}

close $my_kanji_file;

print "\ni_know_kanji.txt\n" unless $dont_attach_txt;

if ( -f "i_know_kanji.txt" ) {
 open my $i_know_kanji_file, '<:encoding(UTF-8)', 'i_know_kanji.txt' or die "Cannot open i_know_kanji.txt\n";

 while (<$i_know_kanji_file>){
  print unless $dont_attach_txt;
  chomp;
  next if /^#/;
  next if /^$/;
  if ( $kanji{$_} ) {
   push(@iknowkanji, $_);
  }
 }

 close $i_know_kanji_file;
}

print "\n-->\n" unless $dont_attach_txt;

#Merge and delete duplicates
my (@usekanji) = do { my %seen ; grep { !$seen{$_}++ and $kanji{$_} } (@mykanji, @iknowkanji) };

#Clear table ...
my $usekanji_tab = $dbh->prepare("drop table if exists usekanji");
$usekanji_tab->execute();
#... recreate it ...
$usekanji_tab = $dbh->prepare("
CREATE TABLE usekanji (
 id integer,
 foreign key (id) references kanji(id)
)
");
$usekanji_tab->execute();
#... insert characters used in this file to filter out needed words
$usekanji_tab = $dbh->prepare("insert into usekanji select id from kanji where id in (".join(',', map { $kanji{$_}{ID} } @usekanji).")");
$usekanji_tab->execute();

print "<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">
 <head>
 <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />
 <title>Kanji Card</title>
 <style type=\"text/css\">
 .kanji-title {
   text-align: center;
 }
 .examples {
   font-size: 15px;
 }
 .left-panel
 {
     background-color:#ccc;
     border-bottom: 1px solid black;
 }
 .right-panel
 {
     background-color:Gray;
     border-bottom: 1px solid black;
 }
 .kanji
 {
     font-size: 64px;
     margin-left: 10px;

 }
 .radicals span {
     font-size: 14px;
 }
 .kun, .on {
     font-size: 26pt;
 }
 a {
     color: black;
     text-decoration: none;
 }
 ul.character-index {
     background-color: #ccc;
     border: 1px solid black;
 }
 div.go-up {
     text-align: right;
 }
 div.go-up a {
     color: black;
     text-decoration: none;
     text-align: right;
 }
 </style>
 </head>
 <body>

";

my %words_seen;
my %suggest_kanji;
my %used_words;
my $character_no=0;

#Generate links

print "<a name=\"top\"></a>
<ul class=\"character-index\">";
#Remove duplicates!
for my $character (do { my %seen; grep { !$seen{$_}++ and $kanji{$_} } @mykanji }) {
 print "<li><a href=\"#kanji-".$character_no."\">".$character_no++.". ".$character."</a></li>
";
}
print "</ul><br/>";

$character_no=0;

#Remove duplicates!
for my $character (do { my %seen; grep { !$seen{$_}++ and $kanji{$_} } @mykanji }) {

 my $radicals_query = $dbh->prepare("select r.id, r.radical, r.meaning, r.type
  from kanjiradicals kr 
  join radicals r on r.id=kr.radical_id 
  where kr.kanji_id=".$kanji{$character}{ID});
 $radicals_query->execute();

 while (my ($radical_id, $radical, $radical_meaning, $radical_type ) = $radicals_query->fetchrow() ) {
  $kanji{$character}{Radicals}{$radical_id}{Radical}=$radical;
  $kanji{$character}{Radicals}{$radical_id}{Meaning}=$radical_meaning;
  $kanji{$character}{Radicals}{$radical_id}{Type}=$radical_type;
 }

 # Find words which have characters from list and order them by 
 # how many of them are used and by word's length,
 # also filter out words seen in previous characters.
 my $words_query = $dbh->prepare("select w.id, w.kanji_reading, w.hiragana_reading, w.meaning, count(usekanji.id), max(w.length), max(w.character_count)
  from words w 
  join kanjiwords kw on kw.word_id = w.id 
  join usekanji on usekanji.id = kw.kanji_id 
  where w.id in (
   select word_id from kanjiwords 
   where kanji_id = ".$kanji{$character}{ID}."
  ) and w.id not in (
   ".join(',', keys %words_seen)."
  ) 
  group by w.ent_seq
  order by ".join(", ", @additional_sort)."count(usekanji.id) desc, w.character_count desc, w.length desc
  limit ".$words_per_character);
 $words_query->execute();

 my @kanji_words;
 while (my ($id, $kanji_reading, $hiragana_reading, $meaning ) = $words_query->fetchrow() ) {
  push(@kanji_words, $kanji_reading." (".$hiragana_reading."):  ".$meaning);
  $words_seen{$id}=1;
 }

 print "<div><!-- main div for character -->
 <div class=\"left-panel\">
 <div class=\"kanji\"><a href=\"#kanji-".$character_no."\" name=\"kanji-".$character_no++."\">".$character."</a></div>
 <div class=\"kun\">Kun: <span>".$kanji{$character}{Kun}."</span></div>
 <div class=\"on\">On: <span>".$kanji{$character}{On}."</span></div>";

 if ( $print_radicals ) {
  print "
   <div class=\"radicals\">Radicals: <br/>
";

  for ( sort { $a <=> $b } keys %{$kanji{$character}{Radicals}}) {
   if ( $kanji{$character}{Radicals}{$_}{Meaning} eq "" ) {
    print "<span>".$kanji{$character}{Radicals}{$_}{Radical}." (".$kanji{$character}{Radicals}{$_}{Type}.")</span><br/>\n";
   } else {
    print "<span>".$kanji{$character}{Radicals}{$_}{Radical}." (".$kanji{$character}{Radicals}{$_}{Type}.") -> ".$kanji{$character}{Radicals}{$_}{Meaning}."</span><br/>\n";
   }
  }
  print "    </div><!-- end radicals -->
 ";
 
 }

print "</div><!-- end left-panel -->
<div class=\"right-panel\">
<div class=\"kanji-title\"><b>".$kanji{$character}{Meaning}."</b></div>
<div class=\"examples\">
";

for (@kanji_words) {
 print "<span class=\"word\">".$_."</span><br/>\n";
}

print "<div class=\"go-up\"><a onclick=\"return confirm('Are you sure?')\" href=\"#top\">Go up</a></div>";

print "</div><!-- end examples -->
</div><!-- end right-panel -->
<div style=\"clear:both\"></div>
</div><!-- end main diff for character -->

";

}

print " </body>
</html>";


if ( $print_suggested_kanji ) {
 $kanji_query = $dbh->prepare("select k.character, count(*) from kanji k
  join kanjiwords kw on kw.kanji_id = k.id
  where kw.word_id in (".join(',', ( keys %words_seen )).")
  and kw.kanji_id not in (".join(',', map { $kanji{$_}{ID} } @usekanji).")
  group by k.character
  order by count(*) desc
  " );
 $kanji_query->execute();
 
 while (my ($character, $count) = $kanji_query->fetchrow() ) {
  print STDERR "Suggested kanji: ".$character." ".$kanji{$character}->{Meaning}.": ".$count."\n";
 }

}
