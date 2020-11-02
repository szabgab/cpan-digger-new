package CPAN::Digger;
use strict;
use warnings;

our $VERSION = '1.00';

use Log::Log4perl ();
use File::Temp qw(tempdir);
use Cwd qw(getcwd);
use Exporter qw(import);

my $tempdir = tempdir( CLEANUP => 1 );


our @EXPORT_OK = qw(get_vcs get_data);

sub get_vcs {
    my ($repository) = @_;
    if ($repository) {
        #        $html .= sprintf qq{<a href="%s">%s %s</a><br>\n}, $repository->{$k}, $k, $repository->{$k};
        # Try to get the web link
        my $url = $repository->{web};
        if (not $url) {
            $url = $repository->{url};
            $url =~ s{^git://}{https://};
            $url =~ s{\.git$}{};
        }
        my $name = "repository";
        if ($url =~ m{^https?://github.com/}) {
            $name = 'GitHub';
        }
        if ($url =~ m{^https?://gitlab.com/}) {
            $name = 'GitLab';
        }
        return $url, $name;
    }
}

sub get_data {
    my ($item) = @_;
    my $logger = Log::Log4perl->get_logger();
    my %data = (
        distribution => $item->distribution,
        version      => $item->version,
        author       => $item->author,
    );

    $logger->debug('dist: ', $item->distribution);
    $logger->debug('      ', $item->author);
    #my @licenses = @{ $item->license };
    #$logger->debug('      ', join ' ', @licenses);
    # if there are not licenses =>
    # if there is a license called "unknonws"
    # check against a known list of licenses (grow it later, or look it up somewhere?)
    my %resources = %{ $item->resources };
    #say '  ', join ' ', keys %resources;
    if ($resources{repository}) {
        my ($vcs_url, $vcs_name) = get_vcs($resources{repository});
        if ($vcs_url) {
            $data{vcs_url} = $vcs_url;
            $data{vcs_name} = $vcs_name;
            $logger->debug("      $vcs_name: $vcs_url");
            if ($vcs_name eq 'GitHub') {
                analyze_github(\%data);
            }
        }
    } else {
        $logger->warn('No repository for ', $item->distribution);
    }
    return %data;
}


sub analyze_github {
    my ($data) = @_;
    my $logger = Log::Log4perl->get_logger();

    my $vcs_url = $data->{vcs_url};
    my $repo_name = (split '\/', $vcs_url)[-1];
    $logger->info("Analyze GitHub repo '$vcs_url' in directory $repo_name");

    my @cmd = ("git", "clone", "--depth", "1", $data->{vcs_url});
    my $cwd = getcwd();
    chdir($tempdir);
    my $exit_code = system(@cmd);
    chdir($cwd);
    my $repo = "$tempdir/$repo_name";

    if ($exit_code != 0) {
        # TODO capture stderr and include in the log
        $logger->error("Failed to clone $vcs_url");
        return;
    }

    $data->{travis} = -e "$repo/.travis.yml";
    $data->{github_actions} = scalar(glob("$repo/.github/workflows/*"));
    $data->{circleci} = -e "$repo/.circleci";
    $data->{appveyor} = (-e "$repo/.appveyor.yml") || (-e "$repo/appveyor.yml");

    for my $ci (qw(travis github_actions circleci appveyor)) {
        if ($data->{$ci}) {
            $data->{has_ci} = 1;
        }
    }
}


42;


=head1 NAME

CPAN::Digger - To dig CPAN

=head1 SYNOPSIS

    cpan-digger

=head1 DESCRIPTION

This is a command line program to collect some meta information about CPAN modules.


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2020 by L<Gabor Szabo|https://szabgab.com/>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.26.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
