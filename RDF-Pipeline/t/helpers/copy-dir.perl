#! /usr/bin/perl -w

# Copy one directory to another, excluding hidden files/directories.
# The destination directory is first deleted.
# As a special case, if the source directory is "/dev/null" (which
# isn't actually a directory, but whatever), then the contents
# of the destination directory are deleted, leaving an empty
# directory.
#
# The -s ("subversion") option says to be svn-aware, which means that if the
# destination directory contains a hidden .svn subdirectory, then
# we will do an "svn rm" to remove the destination directory
# from svn's control before copying the directory.  And after
# copying, we will do an "svn add" to add the destination directory
# back under svn control.  This allows files to be added/removed
# from the destination directory, which svn otherwise would not
# notice or would automatically restore.  THE USE OF SVN MEANS
# THAT THIS SCRIPT MUST BE RUN FROM THE SUBVERSION TRUNK DIRECTORY.

use strict;

my $noisy = 0;

my $svnOption = 0;
if (@ARGV && $ARGV[0] eq "-s") {
	shift @ARGV;
	$svnOption = 1;
	}

@ARGV == 2 or die "Usage: $0 [-s] sourceDir destDir\n";
my $sourceDir = shift @ARGV;
my $destDir = shift @ARGV;

# Make them absolute paths:
my $cwd = `/bin/pwd`;
chomp $cwd;
$cwd =~ s|\/\Z|| if length($cwd)>1;
$sourceDir = "$cwd/$sourceDir" if $sourceDir !~ m|\A\/|;
$destDir = "$cwd/$destDir" if $destDir !~ m|\A\/|;

# warn "copy-dir.perl $sourceDir $destDir\n";

-d $sourceDir || $sourceDir eq "/dev/null"
	or die "$0: Source directory does not exist: $sourceDir\n";

my $useSvn = $svnOption && -d "$destDir/.svn";

if ($useSvn) {
	my $svnCmd = "svn rm -q --force '$destDir'";
	warn "$svnCmd\n" if $noisy;
	!system($svnCmd) or die "Command failed: $svnCmd";
	}
else	{
	if (-d "$destDir/.svn") {
		die "ERROR: Destination directory contains a .svn subdirectory!
If it is under subversion control, then use the -s option.
Otherwise, manually delete the destination directory first.\n" 
		}
	my $rmCmd = "rm -r '$destDir'";
	# warn "rmCmd: $rmCmd\n";
	!system($rmCmd) or die "Command failed: $rmCmd" if -e $destDir;
	}

if ($sourceDir ne "/dev/null") {
	# Copy $sourceDir to $destDir .
	# $sourceDir *must* have a trailing slash, so that rsync won't put it
	# underneath $destDir, as explained in Kaleb Pederson's comment here:
	# http://stackoverflow.com/questions/2193584/copy-folder-recursively-excluding-some-folders
	$sourceDir .= "/" if $sourceDir !~ m|\/\Z|;
	#### Cannot use rsync due to issue #29, 
	#### but tar with --format=posix seems to work.
	# my $copyCmd = "rsync -a '--exclude=.*' '$sourceDir' '$destDir'";
	mkdir($destDir) || die if !-d $destDir;
	my $copyCmd = "cd '$sourceDir' ; /bin/tar cf - '--format=posix' '--exclude-vcs' . | ( cd '$destDir' ; /bin/tar xf - )";
	warn "$copyCmd\n" if $noisy;
	# warn "Copying '$sourceDir' to '$destDir'\n" if $useSvn && $noisy;
	!system($copyCmd) or die;
	}

if ($useSvn) {
	my $svnCmd = "svn add -q '$destDir'";
	warn "$svnCmd\n" if $noisy;
	!system($svnCmd) or die "Command failed: $svnCmd";
	}

exit 0;

