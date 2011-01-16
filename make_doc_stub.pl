#!/usr/bin/perl
use strict;

sub definitions {
	my $file = shift;
	my (@functions, @classes);
	open FP, "<$file" or die "Cannot open `$file': $!\n";
	while (<FP>) {
		chomp;
		push @functions, "$_" if m/^function/;
		push @classes, "$_" if m/Class{/;
	}
	close FP;
	return (functions => \@functions, classes => \@classes);
}

my @html = ();
my $header = <<EOHEADER;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
<title>HardonCollider - A collision detection library</title>
<style type="text/css">
body {
	margin-top: 1.0em;
	background-color: #f7fcfc;
	font-family: "Helvetica,Arial,FreeSans";
	color: #000000;
}

a.top {
	font-size: 8pt;
	margin-left: 1em;
	margin-right: 1em;
	float: right;
}

pre code { border: 0; }
</style>
</head>

<body><a name="top"></a>
EOHEADER
push @html, $header;

my $html_chunk;
for (@ARGV) {
	my $fn = $_;
	my %info = definitions($fn);
	my $module = substr($fn,0, length($fn)-4);

	$html_chunk = <<EOCHUNK;
<a name="$module"></a>
<div id="$module" class="module">
	<div class="name">hardoncollider.$module<a class="top" href="#top">^ top</a></div>
	<div class="preamble">
		<h5 style="color: ref;">Description here</h5>
	</div>

	<div class="overview">
	<h3>Module overview</h3>
		<dl>
EOCHUNK
	push @html, $html_chunk;

	for (@{$info{classes}}) {
		my ($name, $arglist);
		if (m/(\S+).+function\(self,\s+([^\)]*)\)/) {
			($name, $arglist) = ($1,$2);
		}
		my @arguments = split /,\s*/, $arglist;

		$html_chunk = <<EOCHUNK;
			<dt>class<a href="#$module-$name">$name()</a></dt>
			<dd>Short description</dd>
EOCHUNK
		push @html, $html_chunk;
	}

	for (@{$info{functions}}) {
		my ($name, $arglist);
		if (m/^function\s+(\S+)\(([^\)]*)\)$/) {
			($name, $arglist) = ($1, $2);
		}
		$html_chunk = <<EOCHUNK;
			<dt>function <a href="#$module-$name">$name()</a></dt>
			<dd>Short description</dd>
EOCHUNK
		push @html, $html_chunk;
	}
	$html_chunk = <<EOCHUNK;
		</dl>
	</div>
EOCHUNK
	push @html, $html_chunk;

	for (@{$info{classes}}) {
		my ($name, $arglist);
		if (m/(\S+).+function\(self,\s+([^\)]*)\)/) {
			($name, $arglist) = ($1,$2);
		}
		my @arguments = split /,\s*/, $arglist;

		$html_chunk = <<EOCHUNK;
	<a name="$module-$name"></a>
	<div id="$name" class="class">
		<div class="constructor"><span class="name">$name</span><span class="arglist">($arglist)</span><a class="top" href="#$module">^ top</a></div>
		<p>
		<h5 style="color:red;">Description here</h5>
		</p>
		<div class="arguments">Parameters:
			<dl>
EOCHUNK
		push @html, $html_chunk;
		for my $arg (@arguments) {
			$html_chunk = <<EOCHUNK;
				<dt>[type] <code>$arg</code></dt>
				<dd>
				<h5 style="color:red;">Description here</h5>
				</dd>
EOCHUNK
			push @html, $html_chunk;
		}
		$html_chunk = <<EOCHUNK;
			</dl>
		</div>
		<div class="returns">Returns:
			<dl>
				<dt>[type] </dt>
				<dd>
				<h5 style="color:red;">Description here</h5>
				</dd>
			</dl>
		</div>
		<div class="example">Example:
			<pre><code class="lua">
				Example code
			</code></pre>
		</div>
	</div>

EOCHUNK
		push @html, $html_chunk;
	}

	for (@{$info{functions}}) {
		my ($name, $arglist);
		if (m/^function\s+(\S+)\(([^\)]*)\)$/) {
			($name, $arglist) = ($1, $2);
		}
		my @arguments = split /,\s*/, $arglist;

		$html_chunk = <<EOCHUNK;
	<a name="$module-$name"></a>
	<div id="$name" class="function">
		<div class="definition">function <span class="name">$name</span><span class="arglist">($arglist)</span><a class="top" href="#$module">^ top</a></div>
		<p>
		<h5 style="color:red;">Description here</h5>
		</p>
		<div class="arguments">Parameters:
			<dl>
EOCHUNK
		push @html, $html_chunk;
		for my $arg (@arguments) {
			$html_chunk = <<EOCHUNK;
				<dt>[type] <code>$arg</code></dt>
				<dd>
				<h5 style="color:red;">Description here</h5>
				</dd>
EOCHUNK
			push @html, $html_chunk;
		}
		$html_chunk = <<EOCHUNK;
			</dl>
		</div>
		<div class="returns">Returns:
			<dl>
				<dt>[type] </dt>
				<dd>
				<h5 style="color:red;">Description here</h5>
				</dd>
			</dl>
		</div>
		<div class="example">Example:
			<pre><code class="lua">
				Example code
			</code></pre>
		</div>
	</div>

EOCHUNK
		push @html, $html_chunk;
	}
	push @html, "</div>\n";
}

push @html, "</body>\n";

print join "", @html;
