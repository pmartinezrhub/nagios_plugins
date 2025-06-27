#!/usr/bin/perl
# This scripts uses sqlcmd to check status of locks of databases in Nagios, making use of sqlcmd command.
# Author pmartinezr@proton.me GPL v2. 

use strict;
use warnings;
use Getopt::Long;

my ($server, $database, $username, $password, $threshold) = (undef, undef, undef, undef, 5);

GetOptions(
    's=s' => \$server,
    'd=s' => \$database,
    'u=s' => \$username,
    'p=s' => \$password,
    't=i' => \$threshold,
    'h'   => sub { print_help(); exit 0; },
) or die "Error en argumentos. Usa -h para ayuda.\n";

die "Se requiere -s, -d, -u y -p\n" unless defined $server && defined $database && defined $username && defined $password;

my $query = qq{
    SET NOCOUNT ON;
    SELECT COUNT(*) AS Bloqueos
    FROM sys.dm_exec_requests AS r
    JOIN sys.dm_exec_sessions AS s ON r.session_id = s.session_id
    WHERE r.blocking_session_id <> 0
    AND DATEDIFF(minute, s.last_request_start_time, GETDATE()) >= 1;
};

# Escapar comillas simples para sqlcmd
$query =~ s/'/''/g;

my $cmd = qq{sqlcmd -S $server -d $database -U "$username" -P "$password" -h -1 -W -Q "$query"};

my $output = qx{$cmd 2>&1};
if ($? != 0) {
    die "Error ejecutando sqlcmd: $output";
}

$output =~ s/^\s+|\s+$//g;
my ($bloqueos) = $output =~ /(\d+)/;
$bloqueos //= 0;

if ($bloqueos > $threshold) {
    print "CRITICAL: $bloqueos bloqueos activos | bloqueos=$bloqueos\n";
    exit 2;
} elsif ($bloqueos > 0) {
    print "WARNING: $bloqueos bloqueos activos | bloqueos=$bloqueos\n";
    exit 1;
} else {
    print "OK: No hay bloqueos activos | bloqueos=$bloqueos\n";
    exit 0;
}

sub print_help {
    print "Uso: $0 -s SERVER -d DATABASE -u USERNAME -p PASSWORD [-t umbral] [-h]\n";
    print "Chequea bloqueos en SQL Server usando sqlcmd.\n";
}
