package probe_utils;

# IBM(c) 2016 EPL license http://www.eclipse.org/legal/epl-v10.html

use strict;
use File::Path;
use File::Copy;
use Time::Local;
use Socket;

#-----------------------------------------

=head3
    Description:
        Format output message depending on probe framework requirement
        Format is [<flag>] : <message>
        The valid <flag> are debug, warning, failed, info and ok
    Arguments:
        output: where should the message be output 
              The vaild values are:
              stdout : print message to STDOUT
              a file name: print message to the specified "file name" 
        tag:  the type of message, the valid values are:
              d: debug
              w: warning
              f: failed
              o: ok
              i: info

              If tag is NULL, output message without a tag
             
        msg:  the information need to output
     Returns:
        1 : Failed 
        0 : success 
=cut

#----------------------------------------
sub send_msg {
    my $output = shift;
    $output = shift if (($output) && ($output =~ /probe_utils/));
    my $tag = shift;
    my $msg = shift;
    my $flag="";

    if ($tag eq "d") {
        $flag = "[debug]  :";
    } elsif ($tag eq "w") {
        $flag = "[warning]:";
    } elsif ($tag eq "f") {
        $flag = "[failed] :";
    } elsif ($tag eq "o") {
        $flag = "[ok]     :";
    } elsif ($tag eq "i") {
        $flag = "[info]   :";
    }

    if ($output eq "stdout") {
        print "$flag$msg\n";
    } elsif($output) {
        syswrite $output, "$flag$msg\n";
    } else {
        if (!open(LOGFILE, ">> $output")) {
            return 1;
        }
        print LOGFILE "$flag$msg\n";
        close LOGFILE;
    }
    return 0;
}

#------------------------------------------

=head3
    Description:
        Test if a string is a IP address
    Arguments:
        addr: the string want to be judged 
    Returns:
        1 : yes
        0 : no
=cut

#------------------------------------------
sub is_ip_addr {
    my $addr = shift;
    $addr = shift if (($addr) && ($addr =~ /probe_utils/));
    return 0 unless ($addr);
    return 0 if ($addr !~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/);
    return 0 if ($1 > 255 || $1 == 0 || $2 > 255 || $3 > 255 || $4 > 255);
    return 1;
}

#------------------------------------------

=head3
    Description:
        Test if a IP address belongs to a network
    Arguments:
        net : network address, such like 10.10.10.0
        mask: network mask.  suck like 255.255.255.0
        ip:   a ip address
    Returns:
        1 : yes
        0 : no
=cut

#------------------------------------------
sub is_ip_belong_to_net {
    my $net = shift;
    $net = shift if (($net) && ($net =~ /probe_utils/));
    my $mask     = shift;
    my $targetip = shift;

    return 0 if ($net !~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/);
    return 0 if ($mask !~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/);
    return 0 if (!is_ip_addr($targetip));

    my $bin_mask = 0;
    $bin_mask = (($1 + 0) << 24) + (($2 + 0) << 16) + (($3 + 0) << 8) + ($4 + 0) if ($mask =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/);

    my $bin_ip = 0;
    $bin_ip = (($1 + 0) << 24) + (($2 + 0) << 16) + (($3 + 0) << 8) + ($4 + 0) if ($targetip =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/);

    my $tmp_net = $bin_mask & $bin_ip;

    my $bin_net = 0;
    $bin_net = (($1 + 0) << 24) + (($2 + 0) << 16) + (($3 + 0) << 8) + ($4 + 0) if ($net =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/);

    return 0 if ($tmp_net != $bin_net);
    return 1;
}

#------------------------------------------

=head3
   Description:
        Get distro name of current operating system
    Arguments:
        None
    Returns:
        A string, include value are sles, redhat and ubuntu
=cut

#------------------------------------------
sub get_os {
    my $os     = "unknown";
    my $output = `cat /etc/*release* 2>&1`;
    if ($output =~ /suse/i) {
        $os = "sles";
    } elsif ($output =~ /Red Hat/i) {
        $os = "redhat";
    } elsif ($output =~ /ubuntu/i) {
        $os = "ubuntu";
    }

    return $os;
}

#------------------------------------------

=head3
    Description:
        Test if a IP address is a static IP address 
    Arguments:
        ip:   a ip address
        nic:  the network adapter which ip belongs to
    Returns:
        1 : yes
        0 : no
=cut

#------------------------------------------
sub is_static_ip {
    my $ip = shift;
    $ip = shift if (($ip) && ($ip =~ /probe_utils/));
    my $nic = shift;
    my $os  = get_os();
    my $rst = 0;

    if ($os =~ /redhat/) {
        my $output1 = `cat /etc/sysconfig/network-scripts/ifcfg-$nic 2>&1 |grep -i IPADDR`;
        my $output2 = `cat /etc/sysconfig/network-scripts/ifcfg-$nic 2>&1 |grep -i BOOTPROTO`;
        $rst = 1 if (($output1 =~ /$ip/) && ($output2 =~ /static/i));
    } elsif ($os =~ /sles/) {
        my $output1 = `cat /etc/sysconfig/network/ifcfg-$nic 2>&1 |grep -i IPADDR`;
        my $output2 = `cat /etc/sysconfig/network/ifcfg-$nic 2>&1 |grep -i BOOTPROTO`;
        $rst = 1 if (($output1 =~ /$ip/) && ($output2 =~ /static/i));
    } elsif ($os =~ /ubuntu/) {
        my $output = `cat /etc/network/interfaces 2>&1|grep -E "iface\s+$nic"`;
        $rst = 1 if ($output =~ /static/i);
    }
    return $rst;
}

#------------------------------------------

=head3
    Description:
        Test if SELinux is opened in current operating system 
    Arguments:
         None
    Returns:
        1 : yes
        0 : no
=cut

#------------------------------------------
sub is_selinux_enable {
    if (-e "/usr/sbin/selinuxenabled") {
        `/usr/sbin/selinuxenabled`;
        if ($? == 0) {
            return 1;
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

#------------------------------------------

=head3
    Description:
        Test if firewall is opened in current operating system
    Arguments:
         None
    Returns:
        1 : yes
        0 : no
=cut

#------------------------------------------
sub is_firewall_open {
    my $output;
    my $rst = 0;

    my $output = `iptables -nvL -t filter 2>&1`;

    `echo "$output" |grep "Chain INPUT (policy ACCEPT" > /dev/null  2>&1`;
    $rst = 1 if ($?);

    `echo "$output" |grep "Chain FORWARD (policy ACCEPT" > /dev/null  2>&1`;
    $rst = 1 if ($?);

    `echo "$output" |grep "Chain OUTPUT (policy ACCEPT" > /dev/null  2>&1`;
    $rst = 1 if ($?);

    return $rst;
}

#------------------------------------------

=head3
    Description:
        Test if http service is ready to use in current operating system
    Arguments:
        ip:  http server's ip 
        errormsg_ref: (output attribute) if there is something wrong for HTTP service, this attribute save the possible reason.
    Returns:
        1 : yes
        0 : no
=cut

#------------------------------------------
sub is_http_ready {
    my $mnip = shift;
    $mnip = shift if (($mnip) && ($mnip =~ /probe_utils/));
    my $errormsg_ref = shift;

    my $http      = "http://$mnip/install/postscripts/syslog";
    my %httperror = (
    "400" => "The request $http could not be understood by the server due to malformed syntax",
    "401" => "The request requires user authentication.",
    "403" => "The server understood the request, but is refusing to fulfill it.",
    "404" => "The server has not found anything matching the test Request-URI $http.",
    "405" => "The method specified in the Request-Line $http is not allowe.",
    "406" => "The method specified in the Request-Line $http is not acceptable.",
    "408" => "The client did not produce a request within the time that the server was prepared to wait. The client MAY repeat the request without modifications at any later time.",
    "409" => "The request could not be completed due to a conflict with the current state of the resource.",
    "410" => "The requested resource $http is no longer available at the server and no forwarding address is known.",
    "411" => "The server refuses to accept the request without a defined Content- Length.",
    "412" => "The precondition given in one or more of the request-header fields evaluated to false when it was tested on the server.",
    "413" => "The server is refusing to process a request because the request entity is larger than the server is willing or able to process.",
    "414" => "The server is refusing to service the request because the Request-URI is longer than the server is willing to interpret.",
    "415" => "The server is refusing to service the request because the entity of the request is in a format not supported by the requested resource for the requested method.",
    "416" => "Requested Range Not Satisfiable",
    "417" => "The expectation given in an Expect request-header field could not be met by this server",
    "500" => "The server encountered an unexpected condition which prevented it from fulfilling the request.",
    "501" => "The server does not recognize the request method and is not capable of supporting it for any resource.",
    "502" => "The server, while acting as a gateway or proxy, received an invalid response from the upstream server it accessed in attempting to fulfill the reques.",
    "503" => "The server is currently unable to handle the request due to a temporary overloading or maintenance of the server.",
    "504" => "The server, while acting as a gateway or proxy, did not receive a timely response from the upstream server specified by the URI or some other auxiliary server it needed to access in attempting to complete the request.",
    "505" => "The server does not support, or refuses to support, the HTTP protocol version that was used in the request message.");

    rename("./syslog", "./syslog.org") if (-e "./syslog");
    my @outputtmp = `wget $http 2>&1`;
    my $rst       = $?;
    $rst = $rst >> 8;

    if ((!$rst) && (-e "./syslog")) {
        unlink("./syslog");
        rename("./syslog.org", "./syslog") if (-e "./syslog.org");
        return 1;
    } elsif ($rst == 4) {
        $$errormsg_ref = "Network failure, the server refuse connection. Please check if httpd service is running first.";
    } elsif ($rst == 5) {
        $$errormsg_ref = "SSL verification failure, the server refuse connection";
    } elsif ($rst == 6) {
        $$errormsg_ref = "Username/password authentication failure, the server refuse connection";
    } elsif ($rst == 8) {
        my $returncode = $outputtmp[2];
        chomp($returncode);
        $returncode =~ s/.+(\d\d\d).+/$1/g;
        $$errormsg_ref = $httperror{$returncode};
    }
    rename("./syslog.org", "./syslog") if (-e "./syslog.org");
    return 0;
}

#------------------------------------------

=head3
    Description:
        Test if tftp service is ready to use in current operating system
    Arguments:
        ip:  tftp server's ip
    Returns:
        1 : yes
        0 : no
=cut

#------------------------------------------
sub is_tftp_ready {
    my $mnip = shift;
    $mnip = shift if (($mnip) && ($mnip =~ /probe_utils/));

    rename("/tftpboot/tftptestt.tmp", "/tftpboot/tftptestt.tmp.old") if (-e "/tftpboot/tftptestt.tmp");
    rename("./tftptestt.tmp", "./tftptestt.tmp.old") if (-e "./tftptestt.tmp");

    system("touch /tftpboot/tftptestt.tmp");
    my $output = `tftp -4 -v $mnip  -c get tftptestt.tmp`;
    if ((!$?) && (-e "./tftptestt.tmp")) {
        unlink("./tftptestt.tmp");
        rename("./tftptestt.tmp.old", "./tftptestt.tmp") if (-e "./tftptestt.tmp.old");
        rename("/tftpboot/tftptestt.tmp.old", "/tftpboot/tftptestt.tmp") if (-e "/tftpboot/tftptestt.tmp.old");
        return 1;
    } else {
        rename("./tftptestt.tmp.old", "./tftptestt.tmp") if (-e "./tftptestt.tmp.old");
        rename("/tftpboot/tftptestt.tmp.old", "/tftpboot/tftptestt.tmp") if (-e "/tftpboot/tftptestt.tmp.old");
        return 0;
    }
}


#------------------------------------------

=head3
    Description:
        Test if DNS service is ready to use in current operating system
    Arguments:
        ip:  DNS server's ip
    Returns:
        1 : yes
        0 : no
=cut

#------------------------------------------
sub is_dns_ready {
    my $mnip = shift;
    $mnip = shift if (($mnip) && ($mnip =~ /probe_utils/));
    my $serverip = shift;
    my $hostname = shift;
    my $domain   = shift;

    my $output = `nslookup $mnip $serverip 2>&1`;

    if ($?) {
        return 0;
    } else {
        chomp($output);
        my $tmp = grep {$_ =~ "Server:[\t\s]*$serverip"} split(/\n/, $output);
        return 0 if ($tmp == 0);

        $tmp = grep {$_ =~ "name = $hostname\.$domain"} split(/\n/, $output);
        return 0 if ($tmp == 0);
        return 1;
    }
}

#------------------------------------------

=head3
    Description:
        Calculate network address from ip and netmask 
    Arguments:
        ip: ip address
        mask: network mask
    Returns:
        network : The network address
=cut

#------------------------------------------
sub get_network {
    my $ip = shift;
    $ip = shift if (($ip) && ($ip =~ /probe_utils/));
    my $mask = shift;
    my $net  = "";

    return $net if (!is_ip_addr($ip));
    return $net if ($mask !~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/);

    my $bin_mask = unpack("N", inet_aton($mask));
    my $bin_ip   = unpack("N", inet_aton($ip));
    my $net_int32 = $bin_mask & $bin_ip;
    $net = ($net_int32 >> 24) . "." . (($net_int32 >> 16) & 0xff) . "." . (($net_int32 >> 8) & 0xff) . "." . ($net_int32 & 0xff);
    return "$net/$mask";
}

#------------------------------------------

=head3
    Description:
        Check if the free space of specific directory is more than expected value 
    Arguments:
        targetdir: The directory needed to be checked 
        expect_free_space: the expected free space for above directory
    Returns:
        0: the free space of specific directory is less than expected value
        1: the free space of specific directory is more than expected value
        2: the specific directory isn't mounted on standalone disk. it is a part of "/" 
=cut

#------------------------------------------
sub is_dir_has_enough_space{
    my $targetdir=shift;
    $targetdir = shift if (($targetdir) && ($targetdir =~ /probe_utils/));
    my $expect_free_space = shift;
    my @output = `df -k`;

    foreach my $line (@output){
        chomp($line);
        my @line_array = split(/\s+/, $line);
        if($line_array[5] =~ /^$targetdir$/){
            my $left_space = $line_array[3]/1048576;
            if($left_space >= $expect_free_space){
                return 1;
            }else{
                return 0;
            }
        }
    }
    return 2;
}

#------------------------------------------

=head3
    Description:
        Convert node range in Regular Expression to a node name array
    Arguments:
        noderange : the range of node
    Returns:
        An array which contains each node name
=cut

#------------------------------------------
sub parse_node_range {
    my $noderange = shift;
    $noderange= shift if (($noderange) && ($noderange =~ /probe_utils/));
    my @nodeslist = `nodels $noderange`;
    chomp @nodeslist;
    return @nodeslist;
}
1;
