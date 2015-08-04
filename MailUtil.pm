##########################################################################
# Send Mail
# $Id: MailUtil.pm 31114 2014-06-06 19:22:53Z klchu $
##########################################################################
package MailUtil;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use Email::Valid;
use MIME::Lite;
use WebConfig;
use WebUtil;

# Force flush
$| = 1;

my $env         = getEnv();
my $base_url    = $env->{base_url};
my $base_dir    = $env->{base_dir};
my $cgi_url     = $env->{cgi_url};
my $cgi_dir     = $env->{cgi_dir};
my $img_version = $env->{img_version};

# unix sendmail program
my $sendmail = $env->{sendmail};
$sendmail = "/usr/sbin/sendmail" if ( $sendmail eq "" );

# rt-img\@cuba.jgi-psf.org
my $bugmasterEmail = $env->{img_support_email};

sub validateEMail {
    my ($emailAddress) = @_;
    
    return (Email::Valid->address($emailAddress));
}

sub sendMail {
    my ( $emailTo, $ccTo, $subject, $content, $from) = @_;

    $emailTo = $bugmasterEmail if ($emailTo eq '');
    webDie "Invalid email address $emailTo!" if (! validateEMail($emailTo));
	
    my $send_from = "From: $bugmasterEmail\n";
    if($from ne '') {
        $send_from = "From: $from\n";
    }
    
    my $reply_to = "Reply-to: $bugmasterEmail\n";
    if($from ne '') {
        $reply_to = "Reply-to: $from\n";
    }

    my $send_to = "To: $emailTo\n";
    my $cc_to = '';
    $cc_to = "cc: $ccTo\n" if ($ccTo ne '' && validateEMail($ccTo));
    my $subject = "Subject: $subject\n";

    WebUtil::unsetEnvPath();
	open(SENDMAIL, "|$sendmail -t") or webDie "Cannot open $sendmail: $!";
    print SENDMAIL $send_from;
    print SENDMAIL $reply_to; 
    print SENDMAIL $send_to; 
    print SENDMAIL $cc_to if ($cc_to ne '');
	print SENDMAIL $subject;
	print SENDMAIL "Content-type: text/plain\n\n";
	print SENDMAIL $content;
	close(SENDMAIL);

}

sub sendMailAttachment {
    my ( $emailTo, $ccTo, $subject, $content, $outFilePath, $outFile) = @_;

    $emailTo = $bugmasterEmail if ($emailTo eq '');
    webDie "Invalid email address $emailTo!" if (! validateEMail($emailTo));
    webDie "$outFilePath does not exist!" if (! (-e $outFilePath));
    
	# create a new message
	my $msg = MIME::Lite->new(
	   From => $bugmasterEmail,
	   To => $emailTo,
	   Cc => $ccTo,
	   Subject => $subject,
	   Data => $content
	);

	# add the attachment
	$msg->attach(
	    Type => "text/plain",
	    Path => $outFilePath,
	    Filename => $outFile,
	    Disposition => "attachment"
	);

    WebUtil::unsetEnvPath();
    # send the email
	$msg->send();
}

1;
