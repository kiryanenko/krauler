use 5.010;
use strict;
use warnings;

use AnyEvent::HTTP;
use HTML::DOM;
use DDP;
use Tie::IxHash;

my $site = 'http://www.bmstu.ru';
my $max_async = 100;
my $max_urls = 10000;
my $top_size = 10;

my %results;
my @urls = ( $site );

$AnyEvent::HTTP::MAX_PER_HOST = $max_async;

my $cv = AE::cv;
my $current_async = 0;
my $next; $next = sub {
	return unless scalar keys %results < $max_urls;

	while (scalar @urls > 0) {
		return unless $current_async < $max_async;
		my $url = shift @urls;
		next if exists $results{$url};
		$results{$url} = 0;
p $url;

		$cv->begin;
		$current_async++;
		http_get $url, sub {
			my ($body, $hdr) = @_;

			if ($hdr->{Status} =~ /^2/) {
				$results{$url} = $hdr->{'content-length'};
				
				my $dom_tree = new HTML::DOM;
  				$dom_tree->write($body);
  				$dom_tree->close;
  				
				my @a = $dom_tree->getElementsByTagName('a');
				for (@a) {
					my $href = $_->href;
					if ($href =~ m!^($site|/)!) {
						$href =~ s!^/!$site/!;
						push @urls, $href;
					}
				}
			}
	
			$current_async--;
			$next->();			
			$cv->end;
		};
	}
};
$next->();
$cv->recv;

say "Top-$top_size страниц по размеру:";
my %top;
tie %top, "Tie::IxHash";
for (1..$top_size) {
	my $max = $site;
	while (my ($key, $value) = each %results) {
		next if exists $top{$key};
		$max = $key if $value > $results{$max};
	}
	$top{$max} = $results{$max};
}

while (my ($key, $value) = each %top) { say "$key - $value"; }

my $sum = 0;
while (my ($key, $value) = each %results) {
	$sum += $value;
}
say "Cуммарный размер всех страниц = $sum";

