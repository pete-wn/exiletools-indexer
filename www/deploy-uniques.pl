#!/usr/bin/perl

# This is a simple perl script designed to deploy the Unique Item Reports for production
# 
# It copies the appropriate files into a target directory then minifies the javascript
# Note this uses some unix specific commands and extra tools, it's intended for use at 
# exiletools.com but you can modify it to work if desired

$targetDir = "/var/www/html/uniques";

# Purge the current targetDir
print "/bin/rm -rf $targetDir/*\n";
system("/bin/rm -rf $targetDir/*");

# Copy uniques.html
print "/bin/cp html/uniques.html $targetDir/index.html\n";
system("/bin/cp html/uniques.html $targetDir/index.html");

# Copy css
print "/bin/cp -pr html/css $targetDir\n";
system("/bin/cp -pr html/css $targetDir");

# Copy javascript
print "/bin/cp -pr html/js $targetDir\n";
system("/bin/cp -pr html/js $targetDir");

# Replace the DEVELOPMENT VERSION tag
system("/bin/sed -i \'s/DEVELOPMENT VERSION/Version 2.0/\' $targetDir/index.html");

# Minify the es-uniques.js
use JavaScript::Minifier qw(minify);
open(INFILE, "$targetDir/js/es-uniques.js") or die;
open(OUTFILE, ">$targetDir/js/es-uniques.min.js") or die;
minify(input => *INFILE, outfile => *OUTFILE);
close(INFILE);
close(OUTFILE);

# Update the index.html file to use the minified js
system("/bin/sed -i \'s/script src=\"js\\\/es-uniques.js\"/script src=\"js\\\/es-uniques.min.js\"/\' $targetDir/index.html");

