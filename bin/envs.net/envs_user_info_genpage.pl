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

include 'header.php';
?>

	<body id=\"body\" class=\"dark-mode\">
		<div>

			<div class=\"button_back\">
				<pre class=\"clean\"><strong><a href=\"/\">&lt; back</a></strong></pre>
			</div>

			<div id=\"main\">
<div class=\"block\">
<h1><em>recent user updates</em></h1>
<p></p>
</div>

<pre>this is a static list of the pages modified in <code>/home/*/public_html/*</code>. it updates every hour.</pre>
<br />
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
			</div>

<?php include 'footer.php'; ?>";
