use strict;

use constant PRIVATEKEYFILE 		=> "/home/templates/.ssh/key.key";
use constant AUTHORIZEDKEYSFILE 	=> "/home/templates/.ssh/authorized_keys";

# commandline arguments
my ($username, $predicate) = @ARGV;
$username =~ s/^\s+|\s+$//g;
if(not defined $username or $username =~ /[^a-z0-9_-]/i or $username eq ""){
	errorexit("invalid or missing username!", 1);
}

# read content
open(my $fh, "<", AUTHORIZEDKEYSFILE);
# remove all keys of username from content
my (@content, $b);
while(<$fh>){
	if($_ =~ /^##$username\n/){
		$b = 1;
		next;
	}
	if(defined $b){
		$b = undef;
		next;
	}
	if($_ eq "" or $_ =~ /^\n$/){
		next;
	}
	push(@content, $_);
}
close($fh);

if($predicate eq "new"){
	# generate new keypair
	system("ssh-keygen", "-t", "ecdsa", "-b", "521", "-f", PRIVATEKEYFILE, "-P", "", "-q");

	# print private key to console
	system("cat", PRIVATEKEYFILE);
	unlink PRIVATEKEYFILE;

	# get generated public key
	open(my $fh, '<', PRIVATEKEYFILE . ".pub") or errorexit("could not open public key file", 2);
	my $pub = <$fh>; #read first line of publickey file
	$pub =~ s/^\s+|\s+$//g;
	close($fh);

	unlink PRIVATEKEYFILE . ".pub";

	# write new key and username to content
	push(@content, "##$username\n");
	push(@content, "$pub\n");
}

# write content
open(my $fh, '>', AUTHORIZEDKEYSFILE);
print $fh @content;
close($fh);

sub errorexit{
	my($msg, $code) = @_;
	if (not defined $code){
		$code = 1;
	}
	print "$msg\n";
	exit $code;
}