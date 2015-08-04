##########################################################################
# Questions and comments form
#
# $Id: Questions.pm 31512 2014-07-28 17:51:15Z klchu $
##########################################################################
package Questions;

use strict;
use WebConfig;
use WebUtil;
use CGI qw( :standard );
use Data::Dumper;
use LWP::UserAgent;
use MailUtil;

# Force flush
$| = 1;

my $env         = getEnv();
my $base_url    = $env->{base_url};
my $base_dir    = $env->{base_dir};
my $cgi_url     = $env->{cgi_url};
my $cgi_dir     = $env->{cgi_dir};
my $main_cgi    = $env->{main_cgi};
my $img_ken     = $env->{img_ken};
my $img_version = $env->{img_version};
my $tmp_dir     = $env->{tmp_dir};

# if jira form submit fails display error message with the following email
my $jira_email_error = $env->{jira_email_error};
my $jira_email       = $env->{jira_email};
my $jira_email2       = $env->{jira_email2};

#my $jira_submit_url  = $env->{jira_submit_url};

# unix sendmail program
my $sendmail = $env->{sendmail};
$sendmail = "/usr/sbin/sendmail" if ( $sendmail eq "" );

# rt-img\@cuba.jgi-psf.org
my $toEmail = $env->{bugmaster_email};
$toEmail = "klchu\@lbl.gov" if ( $toEmail eq "" );

my $charNumLimit = 2000;                           # max number chars in textarea and other fields

sub dispatch {
    my $page = param("page");
    if ( $page eq "submit" ) {

        # old bug master way form submit
        #processForm();

    } elsif ( $page eq "testform" ) {

        # new jira form 3.2 - ken
        jiraForm();
    } elsif ( $page eq "jirasubmit" ) {

        # new jira form submit 3.2 - ken
        jiraProcess();

    } elsif ( $page eq "test" ) {
        test();

    } else {
        jiraForm();

        #        if($jira_submit_url ne "") {
        #            # new jira form 3.2 - ken
        #            jiraForm();
        #        } else {
        #            # old bug master way
        #
        #            #printForm();
        #        }
    }
}


#
# new 3.2 - jira form
#
sub jiraForm {
    my ($error_message) = @_;

    # form variables - these are only non-null when validating form
    my $subject = param('subject');
    my $message = param('message');
    my $name    = param('name');
    my $email   = param('email');

    print qq{
        <h1>Questions and Comments about IMG</h1>        
    };

    print "<script src='$base_url/questions.js'></script>\n";

    print qq{
    <form name='mainForm' method="post" action="main.cgi" onsubmit="return validateForm($charNumLimit);">
    };

    if ( $error_message ne "" ) {
        print qq{    
        <div id='error' style="display: block;" >
           <div id='error_id'>
           <p> <font color='red'>
           $error_message
           </font></p>
           </div>    
        </div>
        };

    } else {

        print qq{    
        <div id='error' style="display: none;" >
            <div id='error_id'>
            </div>    
        </div>
        };
    }

    print qq{
      <input type="hidden" name="section" value="Questions" />
      <input type="hidden" name="page" value="jirasubmit" />
      
      <p>
      Now using the NEW JIRA <a href='http://issues.jgi-psf.org'>http://issues.jgi-psf.org</a>
      <br/>
      If you request supplementary IMG materials for educational purposes,<br/>
      please provide your full name, affiliation, address, name of course, and course description.
      <br/>
      <br/>
      Fields marked with an <font color='red'>*</font> are required.</p>

      <table class='img' cellspacing="3" cellpadding="5" border="0" width="650">
          <tr class='img'>
            <th class="subhead" width="200" valign="middle"><font color='red'>*</font>Name: </th>
            <td valign="top"><input type="text" name="name" value="$name" size="40" required onKeyDown="limitText(this, $charNumLimit);" onKeyUp="limitText(this, $charNumLimit);"/></td>
          </tr>
          <tr class='img'>
            <th class="subhead" width="200" valign="middle"><font color='red'>*</font>Email: </th>
            <td valign="top"><input type="email" name="email" value="$email" size="40" required onKeyDown="limitText(this, $charNumLimit);" onKeyUp="limitText(this, $charNumLimit);"/></td>
          </tr>

          <tr class='img'>
            <th class="subhead" width="200" valign="middle"><font color='red'>*</font>Subject: </th>
            <td valign="top"><input type="text" name="subject" value="$subject" size="40" required onKeyDown="limitText(this, $charNumLimit);" onKeyUp="limitText(this, $charNumLimit);"/></td>
          </tr>
          <tr class='img'>
            <th class="subhead" width="200" valign="top"><font color='red'>*</font>Message:<br/>($charNumLimit chars. limit)</th>
            <td valign="top">
<textarea name="message" rows="10" cols="60" onKeyDown="limitText(this, $charNumLimit);" onKeyUp="limitText(this, $charNumLimit);">
$message
</textarea>
            </td>
          </tr>
      </table>
    };

    my ( $server, $google_key ) = WebUtil::getGoogleReCaptchaPublicKey();
    if ( $google_key ne "" ) {
        require Captcha::reCAPTCHA;
        print qq{ 
            <p>
            <font color='red'>*</font> 
            To prevent spam and abuse, please enter the text shown in the window below.<br/> 
            ReCaptcha is required to submit your Questions/Comments.
            <br/>
        };
        my $c = Captcha::reCAPTCHA->new;
        my $error;

        # 'red', 'white', 'blackglass', 'clean'
        my %options = ( 'theme' => 'clean' );
        print $c->get_html( "$google_key", $error, $env->{ssl_enabled}, \%options );
        print "</p>\n";
    }

    print qq{
      <p>
        <input class="smdefbutton" type="submit" value="Submit" />
      </p>
    </form>
    };

}

#
# new jira form process form before submiting to jira
# it also validated the form
#
sub jiraProcess {

    #environment variables
    my $remote_addr     = remote_addr();    #$ENV{'REMOTE_ADDR'};
    my $remote_host     = remote_host();    #$ENV{'REMOTE_HOST'};
    my $remote_user     = remote_user();    #$ENV{'REMOTE_USER'};
    my $http_user_agent = user_agent();     #$ENV{'HTTP_USER_AGENT'};
    my $http_cookie     = raw_cookie();     #$ENV{'HTTP_COOKIE'};
    my $hostname = WebUtil::getHostname();
    my $sid = WebUtil::getSessionId();

    #form variables
    my $subject = param('subject');
    my $message = param('message');
    my $name    = param('name');
    my $email   = param('email');

    my $error = "";

    # check for required fields
    if ( blankStr($name) ) {
        $error .= "Name cannot be blank <br/>";
    }
    if ( length($name) > $charNumLimit ) {
        $error .= "Name too long. Must be $charNumLimit characters or less <br/>";
    }

    if ( blankStr($email) ) {
        $error .= "Email cannot be blank <br/>";
    }
    if ( length($email) > $charNumLimit ) {
        $error .= "Email too long. Must be $charNumLimit characters or less <br/>";
    }

    if ( blankStr($subject) ) {
        $error .= "Subject cannot be blank <br/>";
    }
    if ( length($subject) > $charNumLimit ) {
        $error .= "Subject too long. Must be $charNumLimit characters or less <br/>";
    }

    if ( blankStr($message) ) {
        $error .= "Message cannot be blank <br/>";
    }
    if ( length($message) > $charNumLimit ) {
        $error .= "Message too long. Must be $charNumLimit characters or less <br/>";
    }

    if ( !blankStr($email) && !MailUtil::validateEMail($email) ) {
        $error .= "$email is not a valid email address <br/>";
    }

    if ( !blankStr($error) ) {
        jiraForm($error);
        return;
    }

    # now print reCaptcha - form ok
    my ( $server, $google_key ) = WebUtil::getGoogleReCaptchaPrivateKey();
    if ( $google_key ne "" ) {
        require Captcha::reCAPTCHA;
        my $c         = Captcha::reCAPTCHA->new;
        my $challenge = param('recaptcha_challenge_field');
        my $response  = param('recaptcha_response_field');

        # Verify submission
        my $result = $c->check_answer( "$google_key", $ENV{'REMOTE_ADDR'}, $challenge, $response );

        if ( $result->{is_valid} ) {

            #print "Yes!";
            # do noting
            #jiraForm("TEST: reCAptcha was fine can continue and remove from code");
            #return;
        } else {

            # Error
            jiraForm("Incorrect reCaptcha response!");
            return;
        }
    }

    my $userinfo = qq{
From: $name
Email: $email
Subject: $subject

$message

Environment Variables
HTTP_USER_AGENT: $http_user_agent
IMG SYSTEM: $img_version $base_url  
$remote_addr
$remote_host
$remote_user
$hostname
$sid
    };

    $message = $userinfo;

    MailUtil::sendMail($jira_email, '', $subject, $message, $email);

        print qq{
            <h1> Thank You </h1>
            <p>
            Your feedback has been received.
            Thank you for taking time to send us your question or comment.
            <br/>
            You should receive a confirmation email from 
            <b> JGI-Issues $jira_email or $jira_email2 </b>
            <br/>
            To make any additional comments just reply to the email from JGI-Issues.
            <br/>
            The email from JIRA will be in HTML format.
            </p>            
        };

#    my $ua = WebUtil::myLwpUserAgent(); 
#    my $response = $ua->post(
#                              "$jira_submit_url",
#                              {
#                                 "name"            => $name,
#                                 "email"           => $email,
#                                 "subject"         => $subject,
#                                 "message"         => $message,
#                                 "inquiry"         => "imgsupp",
#                                 "http_referer"    => $base_url,
#                                 "remote_addr"     => $remote_addr,
#                                 "remote_host"     => $remote_host,
#                                 "remote_user"     => $remote_user,
#                                 "http_cookie"     => "",
#                                 "http_user_agent" => "",
#                              }
#    );
#
#    my $content = $response->content();
#
#    if ( $response->is_success ) {
#        print qq{
#            <h1> Thank You </h1>
#            <p>
#            Your feedback has been received.
#            Thank you for taking time to send us your question or comment.
#            <br/>
#            You should receive a confirmation email from 
#            <b> JGISupport (JGI Support) jgisupport+imgsupp\@lbl.gov </b>
#            <br/>
#            To make any additional comments just reply to the email from JGISupport.
#            </p>            
#        };
#
#        #print $response->decoded_content;    # or whatever
#    } else {
#
#        print qq{
#        <h1> Error </h1>
#        <p>
#        Something went wrong. <br/>
#        Please report problems directly to: <a href=\"mailto:$jira_email_error\">IMG Support</a></p>
#        <br/>            
#        };
#
#        webError( $response->status_line . " <br/> " . "$cgi_url/$main_cgi" );
#
#    }

}

#
# testing
#
sub test {
    my $subject = param('subject');
    my $message = param('message');
    my $name    = param('name');
    my $email   = param('email');

    print qq{
        <p>
        $name <br/>
        $email <br/>
        $subject <br/>
        $message <br/>
        </p>
    };
}

1;
