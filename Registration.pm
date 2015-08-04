############################################################################
# Registration.pm - User registration page so users can register
#   themselves for a MyIMG account for doing gene annotation
#   (basically adding comments about genes).
#   Currently not used because of security reasons.
#   All valid users should contact JGI first.  A local person
#   gets name, email, and organization information and sets up
#   an account.
#   --es 09/26/2005
############################################################################
package Registration;
my $section = "Registration";
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
   printRegistrationForm
   processRegistration
);
use strict;
use CGI qw( :standard );
use DBI;
use Digest::MD5 qw( md5_base64 );
use WebUtil;
use WebConfig;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $verbose = $env->{ verbose };
my $base_dir = $env->{ base_dir };

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( $page eq "registrationForm" ) {
        printRegistrationForm( );
    }
    elsif( $page eq "processRegistration" ) {
        processRegistration( );
    }
    else {
        printRegistrationForm( );
    }
}

############################################################################
# printRegistrationForm - Print the registration form.
############################################################################
sub printRegistrationForm {
   printMainForm( );
   print "<h1>Registration</h1>\n";
   print "<p>\n"; 
   print "Fields marked * are required.<br/>\n";
   print "</p>\n"; 
   print "<table class='img' border='0'\n";
   printRow( "*Name", "name", "John D. Smith" );
   printRow( "*Desired Username", "username", "jdsmith" );
   printRow( "*Desired Password", "password1" );
   printRow( "*Desired Password (again)", "password2" );
   printRow( "*email", "email", "jdsmith\@microbial-u.edu" );
   printRow( "*Organization", "organization", "Joint Genome Institute" );
   printRow( "Phone", "phone", "925-111-2345" );
   printRow( "Department", "department", "Microbial Genomics" );
   printRow( "Address", "address", "1234 Pathway Ave." );
   printRow( "City", "city", "Walnut Creek" );
   printRow( "State", "state", "CA", 10 );
   printRow( "Country", "country", "United States of America" );
   print "</table>\n";
   print hiddenVar( "section", $section );
   print hiddenVar( "page", "processRegistration" );
   print submit( -name => "Submit", -value => "Submit", 
      -class => "smdefbutton" );
   print nbsp( 1 );
   print reset( -name => "Reset", -value => "Reset", 
      -class => "smbutton" );
   print end_form( );
}

############################################################################
# printRow - Print one table row.
############################################################################
sub printRow {
   my( $label, $varName, $example, $size ) = @_;

   my $sz = 70;
   $sz = $size if $size ne "";
   print "<tr class='img'>\n";
   print "<th class='subhead' nowrap>$label</th>\n";
   print "<td class='img' nowrap>\n";
   my $type = "text";
   $type = "password" if $varName =~ /password/;
   print "<input type='$type' name='$varName' size='$sz' ";
   print "style='background-color:lightyellow' />\n";
   print "<font color='green' size='-1'>(E.g., \"$example\")</font>\n"
     if $example ne "";
   print "</td>\n";
   print "</tr>\n";
}

############################################################################
# paramWrap - Wrap paramter.  Handle leading and lagging spaces
#  and escape SQL quotes.
############################################################################
sub paramWrap {
   my( $par, $notEscapeSingleQuote ) = @_;
   my $s = param( $par );
   $s =~ s/^\s+//;
   $s =~ s/\s+$//;
   $s =~ s/'/''/g if (!$notEscapeSingleQuote);
   return $s;
}

############################################################################
# processRegistration - Process user registration.
############################################################################
sub processRegistration {

   my $dbh = dbLogin( );
   print "<h1>Registration</h1>\n";

   my $name = paramWrap( "name" );
   my $username = paramWrap( "username", 1 );
   my $password1 = paramWrap( "password1" );
   my $password2 = paramWrap( "password2" );
   my $email = paramWrap( "email" );
   my $organization = paramWrap( "organization" );
   my $phone = paramWrap( "phone" );
   my $department = paramWrap( "department" );
   my $address = paramWrap( "address" );
   my $city = paramWrap( "city" );
   my $state = paramWrap( "state" );
   my $country = paramWrap( "country" );

   if( $name eq "" ) {
      webError( "Please enter first and last name." );
   }
   if( $username eq "" ) {
      webError( "Please enter desired user name." );
   }
   if( $password1 eq "" ) {
      webError( "Please enter password." );
   }
   if( $password2 eq "" ) {
      webError( "Please reenter password." );
   }
   if( $email eq "" ) {
      webError( "Please enter email address." );
   }
   if( $organization eq "" ) {
      webError( "Please enter your organization." );
   }
   if( $username !~ /^[a-zA-Z0-9_]+$/ ) {
      webError( "Use only the characters in [a-zA-Z0-9_] for username." );
   }
   if( $password1 ne $password2 ) {
      webError( "Password entries do not match.  Please retype entries." );
   }
   my $sql = qq{
      select count(*)
      from contact
      where username = ?
   };
   my $cur = execSql( $dbh, $sql, $verbose, $username );
   my $cnt = $cur->fetchrow( );
   $cur->finish( );
   if( $cnt > 0 ) {
      webError( "Username '$username' is already taken. " .
        "Please try another one." );
   };
   my $cur = execSql( $dbh, "set transaction read write", $verbose );
   $cur->finish( );
   my $sql = qq{
     select max(contact_oid) from contact
   };
   my $cur = execSql( $dbh, $sql, $verbose );
   my $contact_oid = $cur->fetchrow( );
   $cur->finish( );
   $contact_oid++;
   my $password = md5_base64( $password1 );
   my $sql = qq{
      insert into Contact 
        (contact_oid, name, username, password, email, organization,
	 phone, department, address, city, state, country, add_date )
      values
        ($contact_oid, '$name', '$username', '$password', '$email',
	 '$organization', '$phone', '$department', '$address', '$city',
	 '$state', '$country', sysdate )
   };
   my $cur = execSql( $dbh, $sql, $verbose );
   $cur->finish( );
   my $cur = execSql( $dbh, "commit work", $verbose );
   $cur->finish( );
   #$dbh->disconnect();
   print "<div id='message'>\n";
   print "<p>\n";
   print "Registration for '$username' completed.";
   print "</p>\n";
   print "</div>\n";

}


1;
