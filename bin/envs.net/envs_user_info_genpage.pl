#!/usr/bin/perl
#
# envs.net - this script generates the user_updates.php
# source from pgadey (ctrl-c.club)
# url: https://github.com/pgadey/bin/blob/master/ctrl-c.club/updated.pl
#

print "<?php
// do not touch
// this files is generated by /usr/local/bin/envs.net/envs_user_updated.sh

	\$title = \"envs.net | recent user updates\";
	\$desc = \"envs.net | recent user updates\";

include 'neoenvs_header.php';
?>

<body id=\"body\">

<!-- Back button -->
<nav class=\"sidenav\">
	<a href=\"/\">
		<img src=\"https://envs.net/img/envs_logo_200x200.png\" class=\"site-icon\" title=\"Back to the envs.net homepage\">
	</a>
</nav>

<!-- main panel -->
<main>

	<h1>recent user updates</h1>

	<p>this is a static list of the pages modified in <code>/home/*/public_html/*</code>. it updates every hour.</p>
	
	<ul>\n";

while (<>) {
		chomp;
		($date, $index) = split(/ /, $_);
		$date = `date --date="\@$date" +'%F %H:%M:%S'`;
		$author = $index;
		$file = $index;
		$author =~ s%/home/(\w+)/public_html/(\S+)%$1%;
		$file =~ s%/home/(\w+)/public_html/(\S+)%$2%;
		print "<li><a href=\"https://envs.net/\~$author/\">\~$author</a> (<a href=\"https://envs.net/\~$author/$file\">$file</a>) at $date</li>\n";
};

print "</ul>

</main>

<?php include 'neoenvs_footer.php'; ?>";
