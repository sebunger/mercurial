#require serve

hide outer repo and work in dir without '.hg'
  $ hg init
  $ mkdir dir
  $ cd dir

Tests some basic hgwebdir functionality. Tests setting up paths and
collection, different forms of 404s and the subdirectory support.

  $ mkdir webdir
  $ cd webdir
  $ hg init a
  $ echo a > a/a
  $ hg --cwd a ci -Ama -d'1 0'
  adding a

create a mercurial queue repository

  $ hg --cwd a qinit --config extensions.hgext.mq= -c
  $ hg init b
  $ echo b > b/b
  $ hg --cwd b ci -Amb -d'2 0'
  adding b

create a nested repository

  $ cd b
  $ hg init d
  $ echo d > d/d
  $ hg --cwd d ci -Amd -d'3 0'
  adding d
  $ cd ..
  $ hg init c
  $ echo c > c/c
  $ hg --cwd c ci -Amc -d'3 0'
  adding c

create a subdirectory containing repositories and subrepositories

  $ mkdir notrepo
  $ cd notrepo
  $ hg init e
  $ echo e > e/e
  $ hg --cwd e ci -Ame -d'4 0'
  adding e
  $ hg init e/e2
  $ echo e2 > e/e2/e2
  $ hg --cwd e/e2 ci -Ame2 -d '4 0'
  adding e2
  $ hg init f
  $ echo f > f/f
  $ hg --cwd f ci -Amf -d'4 0'
  adding f
  $ hg init f/f2
  $ echo f2 > f/f2/f2
  $ hg --cwd f/f2 ci -Amf2 -d '4 0'
  adding f2
  $ echo 'f2 = f2' > f/.hgsub
  $ hg -R f ci -Am 'add subrepo' -d'4 0'
  adding .hgsub
  $ cat >> f/.hg/hgrc << EOF
  > [web]
  > name = fancy name for repo f
  > labels = foo, bar
  > EOF
  $ cd ..

add file under the directory which could be shadowed by another repository

  $ mkdir notrepo/f/f3
  $ echo f3/file > notrepo/f/f3/file
  $ hg -R notrepo/f ci -Am 'f3/file'
  adding f3/file
  $ hg -R notrepo/f update null
  0 files updated, 0 files merged, 4 files removed, 0 files unresolved
  $ hg init notrepo/f/f3
  $ cat <<'EOF' > notrepo/f/f3/.hg/hgrc
  > [web]
  > hidden = true
  > EOF

create repository without .hg/store

  $ hg init nostore
  $ rm -R nostore/.hg/store
  $ root=`pwd`
  $ cd ..

serve
  $ cat > paths.conf <<EOF
  > [paths]
  > a=$root/a
  > b=$root/b
  > EOF
  $ hg serve -p $HGPORT -d --pid-file=hg.pid --webdir-conf paths.conf \
  >     -A access-paths.log -E error-paths-1.log
  $ cat hg.pid >> $DAEMON_PIDS

should give a 404 - file does not exist

  $ get-with-headers.py localhost:$HGPORT 'a/file/tip/bork?style=raw'
  404 Not Found
  
  
  error: bork@8580ff50825a50c8f716709acdf8de0deddcd6ab: not found in manifest
  [1]

should succeed

  $ get-with-headers.py localhost:$HGPORT '?style=raw'
  200 Script output follows
  
  
  /a/
  /b/
  
  $ get-with-headers.py localhost:$HGPORT '?style=json'
  200 Script output follows
  
  {
  "entries": [{
  "name": "a",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "b",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }]
  } (no-eol)

  $ get-with-headers.py localhost:$HGPORT 'a/file/tip/a?style=raw'
  200 Script output follows
  
  a
  $ get-with-headers.py localhost:$HGPORT 'b/file/tip/b?style=raw'
  200 Script output follows
  
  b

should give a 404 - repo is not published

  $ get-with-headers.py localhost:$HGPORT 'c/file/tip/c?style=raw'
  404 Not Found
  
  
  error: repository c/file/tip/c not found
  [1]

atom-log without basedir

  $ get-with-headers.py localhost:$HGPORT 'a/atom-log' | grep '<link'
   <link rel="self" href="http://*:$HGPORT/a/atom-log"/> (glob)
   <link rel="alternate" href="http://*:$HGPORT/a/"/> (glob)
    <link href="http://*:$HGPORT/a/rev/8580ff50825a"/> (glob)

rss-log without basedir

  $ get-with-headers.py localhost:$HGPORT 'a/rss-log' | grep '<guid'
      <guid isPermaLink="true">http://*:$HGPORT/a/rev/8580ff50825a</guid> (glob)
  $ cat > paths.conf <<EOF
  > [paths]
  > t/a/=$root/a
  > b=$root/b
  > coll=$root/*
  > rcoll=$root/**
  > star=*
  > starstar=**
  > astar=webdir/a/*
  > EOF
  $ hg serve -p $HGPORT1 -d --pid-file=hg.pid --webdir-conf paths.conf \
  >     -A access-paths.log -E error-paths-2.log
  $ cat hg.pid >> $DAEMON_PIDS

should succeed, slashy names

  $ get-with-headers.py localhost:$HGPORT1 '?style=raw'
  200 Script output follows
  
  
  /t/a/
  /b/
  /coll/a/
  /coll/a/.hg/patches/
  /coll/b/
  /coll/c/
  /coll/notrepo/e/
  /coll/notrepo/f/
  /rcoll/a/
  /rcoll/a/.hg/patches/
  /rcoll/b/
  /rcoll/b/d/
  /rcoll/c/
  /rcoll/notrepo/e/
  /rcoll/notrepo/e/e2/
  /rcoll/notrepo/f/
  /rcoll/notrepo/f/f2/
  /star/webdir/a/
  /star/webdir/a/.hg/patches/
  /star/webdir/b/
  /star/webdir/c/
  /star/webdir/notrepo/e/
  /star/webdir/notrepo/f/
  /starstar/webdir/a/
  /starstar/webdir/a/.hg/patches/
  /starstar/webdir/b/
  /starstar/webdir/b/d/
  /starstar/webdir/c/
  /starstar/webdir/notrepo/e/
  /starstar/webdir/notrepo/e/e2/
  /starstar/webdir/notrepo/f/
  /starstar/webdir/notrepo/f/f2/
  /astar/
  /astar/.hg/patches/
  

  $ get-with-headers.py localhost:$HGPORT1 '?style=json'
  200 Script output follows
  
  {
  "entries": [{
  "name": "t/a",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "b",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "coll/a",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "coll/a/.hg/patches",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "coll/b",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "coll/c",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "coll/notrepo/e",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "fancy name for repo f",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": ["foo", "bar"]
  }, {
  "name": "rcoll/a",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "rcoll/a/.hg/patches",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "rcoll/b",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "rcoll/b/d",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "rcoll/c",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "rcoll/notrepo/e",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "rcoll/notrepo/e/e2",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "fancy name for repo f",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": ["foo", "bar"]
  }, {
  "name": "rcoll/notrepo/f/f2",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "star/webdir/a",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "star/webdir/a/.hg/patches",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "star/webdir/b",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "star/webdir/c",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "star/webdir/notrepo/e",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "fancy name for repo f",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": ["foo", "bar"]
  }, {
  "name": "starstar/webdir/a",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "starstar/webdir/a/.hg/patches",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "starstar/webdir/b",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "starstar/webdir/b/d",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "starstar/webdir/c",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "starstar/webdir/notrepo/e",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "starstar/webdir/notrepo/e/e2",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "fancy name for repo f",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": ["foo", "bar"]
  }, {
  "name": "starstar/webdir/notrepo/f/f2",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "astar",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }, {
  "name": "astar/.hg/patches",
  "description": "unknown",
  "contact": "Foo Bar \u003cfoo.bar@example.com\u003e",
  "lastchange": [*, *], (glob)
  "labels": []
  }]
  } (no-eol)

  $ get-with-headers.py localhost:$HGPORT1 '?style=paper'
  200 Script output follows
  
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
  <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-US">
  <head>
  <link rel="icon" href="/static/hgicon.png" type="image/png" />
  <meta name="robots" content="index, nofollow" />
  <link rel="stylesheet" href="/static/style-paper.css" type="text/css" />
  <script type="text/javascript" src="/static/mercurial.js"></script>
  
  <title>Mercurial repositories index</title>
  </head>
  <body>
  
  <div class="container">
  <div class="menu">
  <a href="https://mercurial-scm.org/">
  <img src="/static/hglogo.png" width=75 height=90 border=0 alt="mercurial" /></a>
  </div>
  <div class="main">
  <h2 class="breadcrumb"><a href="/">Mercurial</a> </h2>
  
  <table class="bigtable">
      <thead>
      <tr>
          <th><a href="?sort=name">Name</a></th>
          <th><a href="?sort=description">Description</a></th>
          <th><a href="?sort=contact">Contact</a></th>
          <th><a href="?sort=lastchange">Last modified</a></th>
          <th>&nbsp;</th>
          <th>&nbsp;</th>
      </tr>
      </thead>
      <tbody class="stripes2">
      
  <tr>
  <td><a href="/t/a/?style=paper">t/a</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/t/a/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/b/?style=paper">b</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/b/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/coll/a/?style=paper">coll/a</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/coll/a/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/coll/a/.hg/patches/?style=paper">coll/a/.hg/patches</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/coll/a/.hg/patches/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/coll/b/?style=paper">coll/b</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/coll/b/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/coll/c/?style=paper">coll/c</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/coll/c/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/coll/notrepo/e/?style=paper">coll/notrepo/e</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/coll/notrepo/e/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/coll/notrepo/f/?style=paper">fancy name for repo f</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/coll/notrepo/f/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/rcoll/a/?style=paper">rcoll/a</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/rcoll/a/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/rcoll/a/.hg/patches/?style=paper">rcoll/a/.hg/patches</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/rcoll/a/.hg/patches/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/rcoll/b/?style=paper">rcoll/b</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/rcoll/b/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/rcoll/b/d/?style=paper">rcoll/b/d</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/rcoll/b/d/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/rcoll/c/?style=paper">rcoll/c</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/rcoll/c/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/rcoll/notrepo/e/?style=paper">rcoll/notrepo/e</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/rcoll/notrepo/e/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/rcoll/notrepo/e/e2/?style=paper">rcoll/notrepo/e/e2</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/rcoll/notrepo/e/e2/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/rcoll/notrepo/f/?style=paper">fancy name for repo f</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/rcoll/notrepo/f/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/rcoll/notrepo/f/f2/?style=paper">rcoll/notrepo/f/f2</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/rcoll/notrepo/f/f2/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/star/webdir/a/?style=paper">star/webdir/a</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/star/webdir/a/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/star/webdir/a/.hg/patches/?style=paper">star/webdir/a/.hg/patches</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/star/webdir/a/.hg/patches/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/star/webdir/b/?style=paper">star/webdir/b</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/star/webdir/b/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/star/webdir/c/?style=paper">star/webdir/c</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/star/webdir/c/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/star/webdir/notrepo/e/?style=paper">star/webdir/notrepo/e</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/star/webdir/notrepo/e/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/star/webdir/notrepo/f/?style=paper">fancy name for repo f</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/star/webdir/notrepo/f/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/starstar/webdir/a/?style=paper">starstar/webdir/a</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/starstar/webdir/a/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/starstar/webdir/a/.hg/patches/?style=paper">starstar/webdir/a/.hg/patches</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/starstar/webdir/a/.hg/patches/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/starstar/webdir/b/?style=paper">starstar/webdir/b</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/starstar/webdir/b/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/starstar/webdir/b/d/?style=paper">starstar/webdir/b/d</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/starstar/webdir/b/d/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/starstar/webdir/c/?style=paper">starstar/webdir/c</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/starstar/webdir/c/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/starstar/webdir/notrepo/e/?style=paper">starstar/webdir/notrepo/e</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/starstar/webdir/notrepo/e/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/starstar/webdir/notrepo/e/e2/?style=paper">starstar/webdir/notrepo/e/e2</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/starstar/webdir/notrepo/e/e2/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/starstar/webdir/notrepo/f/?style=paper">fancy name for repo f</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/starstar/webdir/notrepo/f/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/starstar/webdir/notrepo/f/f2/?style=paper">starstar/webdir/notrepo/f/f2</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/starstar/webdir/notrepo/f/f2/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/astar/?style=paper">astar</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/astar/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
  <tr>
  <td><a href="/astar/.hg/patches/?style=paper">astar/.hg/patches</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/astar/.hg/patches/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
      </tbody>
  </table>
  </div>
  </div>
  
  
  </body>
  </html>
  
  $ get-with-headers.py localhost:$HGPORT1 't?style=raw'
  200 Script output follows
  
  
  /t/a/
  
  $ get-with-headers.py localhost:$HGPORT1 't/?style=raw'
  200 Script output follows
  
  
  /t/a/
  
  $ get-with-headers.py localhost:$HGPORT1 't/?style=paper'
  200 Script output follows
  
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
  <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-US">
  <head>
  <link rel="icon" href="/static/hgicon.png" type="image/png" />
  <meta name="robots" content="index, nofollow" />
  <link rel="stylesheet" href="/static/style-paper.css" type="text/css" />
  <script type="text/javascript" src="/static/mercurial.js"></script>
  
  <title>Mercurial repositories index</title>
  </head>
  <body>
  
  <div class="container">
  <div class="menu">
  <a href="https://mercurial-scm.org/">
  <img src="/static/hglogo.png" width=75 height=90 border=0 alt="mercurial" /></a>
  </div>
  <div class="main">
  <h2 class="breadcrumb"><a href="/">Mercurial</a> &gt; <a href="/t">t</a> </h2>
  
  <table class="bigtable">
      <thead>
      <tr>
          <th><a href="?sort=name">Name</a></th>
          <th><a href="?sort=description">Description</a></th>
          <th><a href="?sort=contact">Contact</a></th>
          <th><a href="?sort=lastchange">Last modified</a></th>
          <th>&nbsp;</th>
          <th>&nbsp;</th>
      </tr>
      </thead>
      <tbody class="stripes2">
      
  <tr>
  <td><a href="/t/a/?style=paper">a</a></td>
  <td>unknown</td>
  <td>&#70;&#111;&#111;&#32;&#66;&#97;&#114;&#32;&#60;&#102;&#111;&#111;&#46;&#98;&#97;&#114;&#64;&#101;&#120;&#97;&#109;&#112;&#108;&#101;&#46;&#99;&#111;&#109;&#62;</td>
  <td class="age">*</td> (glob)
  <td class="indexlinks"></td>
  <td>
  <a href="/t/a/atom-log" title="subscribe to repository atom feed">
  <img class="atom-logo" src="/static/feed-icon-14x14.png" alt="subscribe to repository atom feed">
  </a>
  </td>
  </tr>
  
      </tbody>
  </table>
  </div>
  </div>
  
  
  </body>
  </html>
  
  $ get-with-headers.py localhost:$HGPORT1 't/a?style=atom'
  200 Script output follows
  
  <?xml version="1.0" encoding="ascii"?>
  <feed xmlns="http://www.w3.org/2005/Atom">
   <!-- Changelog -->
   <id>http://*:$HGPORT1/t/a/</id> (glob)
   <link rel="self" href="http://*:$HGPORT1/t/a/atom-log"/> (glob)
   <link rel="alternate" href="http://*:$HGPORT1/t/a/"/> (glob)
   <title>t/a Changelog</title>
   <updated>1970-01-01T00:00:01+00:00</updated>
  
   <entry>
    <title>[default] a</title>
    <id>http://*:$HGPORT1/t/a/#changeset-8580ff50825a50c8f716709acdf8de0deddcd6ab</id> (glob)
    <link href="http://*:$HGPORT1/t/a/rev/8580ff50825a"/> (glob)
    <author>
     <name>test</name>
     <email>&#116;&#101;&#115;&#116;</email>
    </author>
    <updated>1970-01-01T00:00:01+00:00</updated>
    <published>1970-01-01T00:00:01+00:00</published>
    <content type="xhtml">
     <table xmlns="http://www.w3.org/1999/xhtml">
      <tr>
       <th style="text-align:left;">changeset</th>
       <td>8580ff50825a</td>
      </tr>
      <tr>
       <th style="text-align:left;">branch</th>
       <td>default</td>
      </tr>
      <tr>
       <th style="text-align:left;">bookmark</th>
       <td></td>
      </tr>
      <tr>
       <th style="text-align:left;">tag</th>
       <td>tip</td>
      </tr>
      <tr>
       <th style="text-align:left;">user</th>
       <td>&#116;&#101;&#115;&#116;</td>
      </tr>
      <tr>
       <th style="text-align:left;vertical-align:top;">description</th>
       <td>a</td>
      </tr>
      <tr>
       <th style="text-align:left;vertical-align:top;">files</th>
       <td>a<br /></td>
      </tr>
     </table>
    </content>
   </entry>
  
  </feed>
  $ get-with-headers.py localhost:$HGPORT1 't/a/?style=atom'
  200 Script output follows
  
  <?xml version="1.0" encoding="ascii"?>
  <feed xmlns="http://www.w3.org/2005/Atom">
   <!-- Changelog -->
   <id>http://*:$HGPORT1/t/a/</id> (glob)
   <link rel="self" href="http://*:$HGPORT1/t/a/atom-log"/> (glob)
   <link rel="alternate" href="http://*:$HGPORT1/t/a/"/> (glob)
   <title>t/a Changelog</title>
   <updated>1970-01-01T00:00:01+00:00</updated>
  
   <entry>
    <title>[default] a</title>
    <id>http://*:$HGPORT1/t/a/#changeset-8580ff50825a50c8f716709acdf8de0deddcd6ab</id> (glob)
    <link href="http://*:$HGPORT1/t/a/rev/8580ff50825a"/> (glob)
    <author>
     <name>test</name>
     <email>&#116;&#101;&#115;&#116;</email>
    </author>
    <updated>1970-01-01T00:00:01+00:00</updated>
    <published>1970-01-01T00:00:01+00:00</published>
    <content type="xhtml">
     <table xmlns="http://www.w3.org/1999/xhtml">
      <tr>
       <th style="text-align:left;">changeset</th>
       <td>8580ff50825a</td>
      </tr>
      <tr>
       <th style="text-align:left;">branch</th>
       <td>default</td>
      </tr>
      <tr>
       <th style="text-align:left;">bookmark</th>
       <td></td>
      </tr>
      <tr>
       <th style="text-align:left;">tag</th>
       <td>tip</td>
      </tr>
      <tr>
       <th style="text-align:left;">user</th>
       <td>&#116;&#101;&#115;&#116;</td>
      </tr>
      <tr>
       <th style="text-align:left;vertical-align:top;">description</th>
       <td>a</td>
      </tr>
      <tr>
       <th style="text-align:left;vertical-align:top;">files</th>
       <td>a<br /></td>
      </tr>
     </table>
    </content>
   </entry>
  
  </feed>
  $ get-with-headers.py localhost:$HGPORT1 't/a/file/tip/a?style=raw'
  200 Script output follows
  
  a

Test [paths] '*' extension

  $ get-with-headers.py localhost:$HGPORT1 'coll/?style=raw'
  200 Script output follows
  
  
  /coll/a/
  /coll/a/.hg/patches/
  /coll/b/
  /coll/c/
  /coll/notrepo/e/
  /coll/notrepo/f/
  
  $ get-with-headers.py localhost:$HGPORT1 'coll/a/file/tip/a?style=raw'
  200 Script output follows
  
  a

Test [paths] '**' extension

  $ get-with-headers.py localhost:$HGPORT1 'rcoll/?style=raw'
  200 Script output follows
  
  
  /rcoll/a/
  /rcoll/a/.hg/patches/
  /rcoll/b/
  /rcoll/b/d/
  /rcoll/c/
  /rcoll/notrepo/e/
  /rcoll/notrepo/e/e2/
  /rcoll/notrepo/f/
  /rcoll/notrepo/f/f2/
  
  $ get-with-headers.py localhost:$HGPORT1 'rcoll/b/d/file/tip/d?style=raw'
  200 Script output follows
  
  d

Test collapse = True

  $ killdaemons.py
  $ cat >> paths.conf <<EOF
  > [web]
  > collapse=true
  > descend = true
  > EOF
  $ hg serve -p $HGPORT1 -d --pid-file=hg.pid --webdir-conf paths.conf \
  >     -A access-paths.log -E error-paths-3.log
  $ cat hg.pid >> $DAEMON_PIDS
  $ get-with-headers.py localhost:$HGPORT1 'coll/?style=raw'
  200 Script output follows
  
  
  /coll/a/
  /coll/a/.hg/patches/
  /coll/b/
  /coll/c/
  /coll/notrepo/
  
  $ get-with-headers.py localhost:$HGPORT1 'coll/a/file/tip/a?style=raw'
  200 Script output follows
  
  a
  $ get-with-headers.py localhost:$HGPORT1 'rcoll/?style=raw'
  200 Script output follows
  
  
  /rcoll/a/
  /rcoll/a/.hg/patches/
  /rcoll/b/
  /rcoll/b/d/
  /rcoll/c/
  /rcoll/notrepo/
  
  $ get-with-headers.py localhost:$HGPORT1 'rcoll/b/d/file/tip/d?style=raw'
  200 Script output follows
  
  d

Test intermediate directories

Hide the subrepo parent

  $ cp $root/notrepo/f/.hg/hgrc $root/notrepo/f/.hg/hgrc.bak
  $ cat >> $root/notrepo/f/.hg/hgrc << EOF
  > [web]
  > hidden = True
  > EOF

  $ get-with-headers.py localhost:$HGPORT1 'rcoll/notrepo/?style=raw'
  200 Script output follows
  
  
  /rcoll/notrepo/e/
  /rcoll/notrepo/e/e2/
  

Subrepo parent not hidden
  $ mv $root/notrepo/f/.hg/hgrc.bak $root/notrepo/f/.hg/hgrc

  $ get-with-headers.py localhost:$HGPORT1 'rcoll/notrepo/?style=raw'
  200 Script output follows
  
  
  /rcoll/notrepo/e/
  /rcoll/notrepo/e/e2/
  /rcoll/notrepo/f/
  /rcoll/notrepo/f/f2/
  

Test repositories inside intermediate directories

  $ get-with-headers.py localhost:$HGPORT1 'rcoll/notrepo/e/file/tip/e?style=raw'
  200 Script output follows
  
  e

Test subrepositories inside intermediate directories

  $ get-with-headers.py localhost:$HGPORT1 'rcoll/notrepo/f/f2/file/tip/f2?style=raw'
  200 Script output follows
  
  f2

Test accessing file that could be shadowed by another repository if the URL
path were audited as a working-directory path:

  $ get-with-headers.py localhost:$HGPORT1 'rcoll/notrepo/f/file/tip/f3/file?style=raw'
  200 Script output follows
  
  f3/file

Test accessing working-directory file that is shadowed by another repository

  $ get-with-headers.py localhost:$HGPORT1 'rcoll/notrepo/f/file/ffffffffffff/f3/file?style=raw'
  403 Forbidden
  
  
  error: path 'f3/file' is inside nested repo 'f3'
  [1]

Test accessing invalid paths:

  $ get-with-headers.py localhost:$HGPORT1 'rcoll/notrepo/f/file/tip/..?style=raw'
  403 Forbidden
  
  
  error: .. not under root '$TESTTMP/dir/webdir/notrepo/f'
  [1]

  $ get-with-headers.py localhost:$HGPORT1 'rcoll/notrepo/f/file/tip/.hg/hgrc?style=raw'
  403 Forbidden
  
  
  error: path contains illegal component: .hg/hgrc
  [1]

Test descend = False

  $ killdaemons.py
  $ cat >> paths.conf <<EOF
  > descend=false
  > EOF
  $ hg serve -p $HGPORT1 -d --pid-file=hg.pid --webdir-conf paths.conf \
  >     -A access-paths.log -E error-paths-4.log
  $ cat hg.pid >> $DAEMON_PIDS
  $ get-with-headers.py localhost:$HGPORT1 'coll/?style=raw'
  200 Script output follows
  
  
  /coll/a/
  /coll/b/
  /coll/c/
  
  $ get-with-headers.py localhost:$HGPORT1 'coll/a/file/tip/a?style=raw'
  200 Script output follows
  
  a
  $ get-with-headers.py localhost:$HGPORT1 'rcoll/?style=raw'
  200 Script output follows
  
  
  /rcoll/a/
  /rcoll/b/
  /rcoll/c/
  
  $ get-with-headers.py localhost:$HGPORT1 'rcoll/b/d/file/tip/d?style=raw'
  200 Script output follows
  
  d

Test intermediate directories

  $ get-with-headers.py localhost:$HGPORT1 'rcoll/notrepo/?style=raw'
  200 Script output follows
  
  
  /rcoll/notrepo/e/
  /rcoll/notrepo/f/
  

Test repositories inside intermediate directories

  $ get-with-headers.py localhost:$HGPORT1 'rcoll/notrepo/e/file/tip/e?style=raw'
  200 Script output follows
  
  e

Test subrepositories inside intermediate directories

  $ get-with-headers.py localhost:$HGPORT1 'rcoll/notrepo/f/f2/file/tip/f2?style=raw'
  200 Script output follows
  
  f2

Test [paths] '*' in a repo root

  $ hg id http://localhost:$HGPORT1/astar
  8580ff50825a

  $ killdaemons.py
  $ cat > paths.conf <<EOF
  > [paths]
  > t/a = $root/a
  > t/b = $root/b
  > c = $root/c
  > EOF
  $ hg serve -p $HGPORT1 -d --pid-file=hg.pid --webdir-conf paths.conf \
  >     -A access-paths.log -E error-paths-5.log
  $ cat hg.pid >> $DAEMON_PIDS
  $ get-with-headers.py localhost:$HGPORT1 '?style=raw'
  200 Script output follows
  
  
  /t/a/
  /t/b/
  /c/
  
  $ get-with-headers.py localhost:$HGPORT1 't/?style=raw'
  200 Script output follows
  
  
  /t/a/
  /t/b/
  

Test collapse = True

  $ killdaemons.py
  $ cat >> paths.conf <<EOF
  > [web]
  > collapse=true
  > EOF
  $ hg serve -p $HGPORT1 -d --pid-file=hg.pid --webdir-conf paths.conf \
  >     -A access-paths.log -E error-paths-6.log
  $ cat hg.pid >> $DAEMON_PIDS
  $ get-with-headers.py localhost:$HGPORT1 '?style=raw'
  200 Script output follows
  
  
  /t/
  /c/
  
  $ get-with-headers.py localhost:$HGPORT1 't/?style=raw'
  200 Script output follows
  
  
  /t/a/
  /t/b/
  

test descend = False

  $ killdaemons.py
  $ cat >> paths.conf <<EOF
  > descend=false
  > EOF
  $ hg serve -p $HGPORT1 -d --pid-file=hg.pid --webdir-conf paths.conf \
  >     -A access-paths.log -E error-paths-7.log
  $ cat hg.pid >> $DAEMON_PIDS
  $ get-with-headers.py localhost:$HGPORT1 '?style=raw'
  200 Script output follows
  
  
  /c/
  
  $ get-with-headers.py localhost:$HGPORT1 't/?style=raw'
  200 Script output follows
  
  
  /t/a/
  /t/b/
  
  $ killdaemons.py
  $ cat > paths.conf <<EOF
  > [paths]
  > nostore = $root/nostore
  > inexistent = $root/inexistent
  > EOF
  $ hg serve -p $HGPORT1 -d --pid-file=hg.pid --webdir-conf paths.conf \
  >     -A access-paths.log -E error-paths-8.log
  $ cat hg.pid >> $DAEMON_PIDS

test inexistent and inaccessible repo should be ignored silently

  $ get-with-headers.py localhost:$HGPORT1 ''
  200 Script output follows
  
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
  <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-US">
  <head>
  <link rel="icon" href="/static/hgicon.png" type="image/png" />
  <meta name="robots" content="index, nofollow" />
  <link rel="stylesheet" href="/static/style-paper.css" type="text/css" />
  <script type="text/javascript" src="/static/mercurial.js"></script>
  
  <title>Mercurial repositories index</title>
  </head>
  <body>
  
  <div class="container">
  <div class="menu">
  <a href="https://mercurial-scm.org/">
  <img src="/static/hglogo.png" width=75 height=90 border=0 alt="mercurial" /></a>
  </div>
  <div class="main">
  <h2 class="breadcrumb"><a href="/">Mercurial</a> </h2>
  
  <table class="bigtable">
      <thead>
      <tr>
          <th><a href="?sort=name">Name</a></th>
          <th><a href="?sort=description">Description</a></th>
          <th><a href="?sort=contact">Contact</a></th>
          <th><a href="?sort=lastchange">Last modified</a></th>
          <th>&nbsp;</th>
          <th>&nbsp;</th>
      </tr>
      </thead>
      <tbody class="stripes2">
      
      </tbody>
  </table>
  </div>
  </div>
  
  
  </body>
  </html>
  

test listening address/port specified by web-conf (issue4699):

  $ killdaemons.py
  $ cat >> paths.conf <<EOF
  > [web]
  > address = localhost
  > port = $HGPORT1
  > EOF
  $ hg serve -d --pid-file=hg.pid --web-conf paths.conf \
  >     -A access-paths.log -E error-paths-9.log
  listening at http://*:$HGPORT1/ (bound to *$LOCALIP*:$HGPORT1) (glob) (?)
  $ cat hg.pid >> $DAEMON_PIDS
  $ get-with-headers.py localhost:$HGPORT1 '?style=raw'
  200 Script output follows
  
  
  
test --port option overrides web.port:

  $ killdaemons.py
  $ hg serve -p $HGPORT2 -d -v --pid-file=hg.pid --web-conf paths.conf \
  >     -A access-paths.log -E error-paths-10.log
  listening at http://*:$HGPORT2/ (bound to *$LOCALIP*:$HGPORT2) (glob) (?)
  $ cat hg.pid >> $DAEMON_PIDS
  $ get-with-headers.py localhost:$HGPORT2 '?style=raw'
  200 Script output follows
  
  
  

  $ killdaemons.py
  $ cat > collections.conf <<EOF
  > [collections]
  > $root=$root
  > EOF
  $ hg serve --config web.baseurl=http://hg.example.com:8080/ -p $HGPORT2 -d \
  >     --pid-file=hg.pid --webdir-conf collections.conf \
  >     -A access-collections.log -E error-collections.log
  $ cat hg.pid >> $DAEMON_PIDS

collections: should succeed

  $ get-with-headers.py localhost:$HGPORT2 '?style=raw'
  200 Script output follows
  
  
  /a/
  /a/.hg/patches/
  /b/
  /c/
  /notrepo/e/
  /notrepo/f/
  
  $ get-with-headers.py localhost:$HGPORT2 'a/file/tip/a?style=raw'
  200 Script output follows
  
  a
  $ get-with-headers.py localhost:$HGPORT2 'b/file/tip/b?style=raw'
  200 Script output follows
  
  b
  $ get-with-headers.py localhost:$HGPORT2 'c/file/tip/c?style=raw'
  200 Script output follows
  
  c

atom-log with basedir /

  $ get-with-headers.py localhost:$HGPORT2 'a/atom-log' | grep '<link'
   <link rel="self" href="http://hg.example.com:8080/a/atom-log"/>
   <link rel="alternate" href="http://hg.example.com:8080/a/"/>
    <link href="http://hg.example.com:8080/a/rev/8580ff50825a"/>

rss-log with basedir /

  $ get-with-headers.py localhost:$HGPORT2 'a/rss-log' | grep '<guid'
      <guid isPermaLink="true">http://hg.example.com:8080/a/rev/8580ff50825a</guid>
  $ killdaemons.py
  $ hg serve --config web.baseurl=http://hg.example.com:8080/foo/ -p $HGPORT2 -d \
  >     --pid-file=hg.pid --webdir-conf collections.conf \
  >     -A access-collections-2.log -E error-collections-2.log
  $ cat hg.pid >> $DAEMON_PIDS

atom-log with basedir /foo/

  $ get-with-headers.py localhost:$HGPORT2 'a/atom-log' | grep '<link'
   <link rel="self" href="http://hg.example.com:8080/foo/a/atom-log"/>
   <link rel="alternate" href="http://hg.example.com:8080/foo/a/"/>
    <link href="http://hg.example.com:8080/foo/a/rev/8580ff50825a"/>

rss-log with basedir /foo/

  $ get-with-headers.py localhost:$HGPORT2 'a/rss-log' | grep '<guid'
      <guid isPermaLink="true">http://hg.example.com:8080/foo/a/rev/8580ff50825a</guid>

Path refreshing works as expected

  $ killdaemons.py
  $ mkdir $root/refreshtest
  $ hg init $root/refreshtest/a
  $ cat > paths.conf << EOF
  > [paths]
  > / = $root/refreshtest/*
  > EOF
  $ hg serve -p $HGPORT1 -d --pid-file hg.pid --webdir-conf paths.conf
  $ cat hg.pid >> $DAEMON_PIDS

  $ get-with-headers.py localhost:$HGPORT1 '?style=raw'
  200 Script output follows
  
  
  /a/
  

By default refreshing occurs every 20s and a new repo won't be listed
immediately.

  $ hg init $root/refreshtest/b
  $ get-with-headers.py localhost:$HGPORT1 '?style=raw'
  200 Script output follows
  
  
  /a/
  

Restart the server with no refresh interval. New repo should appear
immediately.

  $ killdaemons.py
  $ cat > paths.conf << EOF
  > [web]
  > refreshinterval = -1
  > [paths]
  > / = $root/refreshtest/*
  > EOF
  $ hg serve -p $HGPORT1 -d --pid-file hg.pid --webdir-conf paths.conf
  $ cat hg.pid >> $DAEMON_PIDS

  $ get-with-headers.py localhost:$HGPORT1 '?style=raw'
  200 Script output follows
  
  
  /a/
  /b/
  

  $ hg init $root/refreshtest/c
  $ get-with-headers.py localhost:$HGPORT1 '?style=raw'
  200 Script output follows
  
  
  /a/
  /b/
  /c/
  
  $ killdaemons.py
  $ cat > paths.conf << EOF
  > [paths]
  > /dir1/a_repo = $root/a
  > /dir1/a_repo/b_repo = $root/b
  > /dir1/dir2/index = $root/b
  > EOF
  $ hg serve -p $HGPORT1 -d --pid-file hg.pid --webdir-conf paths.conf
  $ cat hg.pid >> $DAEMON_PIDS

  $ echo 'index file' > $root/a/index
  $ hg --cwd $root/a ci -Am 'add index file'
  adding index

  $ get-with-headers.py localhost:$HGPORT1 '' | grep 'a_repo'
  <td><a href="/dir1/a_repo/">dir1/a_repo</a></td>
  <a href="/dir1/a_repo/atom-log" title="subscribe to repository atom feed">
  <td><a href="/dir1/a_repo/b_repo/">dir1/a_repo/b_repo</a></td>
  <a href="/dir1/a_repo/b_repo/atom-log" title="subscribe to repository atom feed">

  $ get-with-headers.py localhost:$HGPORT1 'index' | grep 'a_repo'
  <td><a href="/dir1/a_repo/">dir1/a_repo</a></td>
  <a href="/dir1/a_repo/atom-log" title="subscribe to repository atom feed">
  <td><a href="/dir1/a_repo/b_repo/">dir1/a_repo/b_repo</a></td>
  <a href="/dir1/a_repo/b_repo/atom-log" title="subscribe to repository atom feed">

  $ get-with-headers.py localhost:$HGPORT1 'dir1' | grep 'a_repo'
  <td><a href="/dir1/a_repo/">a_repo</a></td>
  <a href="/dir1/a_repo/atom-log" title="subscribe to repository atom feed">
  <td><a href="/dir1/a_repo/b_repo/">a_repo/b_repo</a></td>
  <a href="/dir1/a_repo/b_repo/atom-log" title="subscribe to repository atom feed">

  $ get-with-headers.py localhost:$HGPORT1 'dir1/index' | grep 'a_repo'
  <td><a href="/dir1/a_repo/">a_repo</a></td>
  <a href="/dir1/a_repo/atom-log" title="subscribe to repository atom feed">
  <td><a href="/dir1/a_repo/b_repo/">a_repo/b_repo</a></td>
  <a href="/dir1/a_repo/b_repo/atom-log" title="subscribe to repository atom feed">

  $ get-with-headers.py localhost:$HGPORT1 'dir1/a_repo' | grep 'a_repo'
  <link rel="icon" href="/dir1/a_repo/static/hgicon.png" type="image/png" />
  <link rel="stylesheet" href="/dir1/a_repo/static/style-paper.css" type="text/css" />
  <script type="text/javascript" src="/dir1/a_repo/static/mercurial.js"></script>
  <title>dir1/a_repo: log</title>
     href="/dir1/a_repo/atom-log" title="Atom feed for dir1/a_repo" />
     href="/dir1/a_repo/rss-log" title="RSS feed for dir1/a_repo" />
  <img src="/dir1/a_repo/static/hglogo.png" alt="mercurial" /></a>
  <li><a href="/dir1/a_repo/graph/tip">graph</a></li>
  <li><a href="/dir1/a_repo/tags">tags</a></li>
  <li><a href="/dir1/a_repo/bookmarks">bookmarks</a></li>
  <li><a href="/dir1/a_repo/branches">branches</a></li>
  <li><a href="/dir1/a_repo/rev/tip">changeset</a></li>
  <li><a href="/dir1/a_repo/file/tip">browse</a></li>
   <li><a href="/dir1/a_repo/help">help</a></li>
  <a href="/dir1/a_repo/atom-log" title="subscribe to atom feed">
  <img class="atom-logo" src="/dir1/a_repo/static/feed-icon-14x14.png" alt="atom feed" />
  <h2 class="breadcrumb"><a href="/">Mercurial</a> &gt; <a href="/dir1">dir1</a> &gt; <a href="/dir1/a_repo">a_repo</a> </h2>
  <form class="search" action="/dir1/a_repo/log">
  number or hash, or <a href="/dir1/a_repo/help/revsets">revset expression</a>.</div>
  <a href="/dir1/a_repo/shortlog/tip?revcount=30">less</a>
  <a href="/dir1/a_repo/shortlog/tip?revcount=120">more</a>
  | rev 1: <a href="/dir1/a_repo/shortlog/8580ff50825a">(0)</a> <a href="/dir1/a_repo/shortlog/tip">tip</a> 
     <a href="/dir1/a_repo/rev/71a89161f014">add index file</a>
     <a href="/dir1/a_repo/rev/8580ff50825a">a</a>
  <a href="/dir1/a_repo/shortlog/tip?revcount=30">less</a>
  <a href="/dir1/a_repo/shortlog/tip?revcount=120">more</a>
  | rev 1: <a href="/dir1/a_repo/shortlog/8580ff50825a">(0)</a> <a href="/dir1/a_repo/shortlog/tip">tip</a> 
              '/dir1/a_repo/shortlog/%next%',

  $ get-with-headers.py localhost:$HGPORT1 'dir1/a_repo/index' | grep 'a_repo'
  <h2 class="breadcrumb"><a href="/">Mercurial</a> &gt; <a href="/dir1">dir1</a> &gt; <a href="/dir1/a_repo">a_repo</a> </h2>
  <td><a href="/dir1/a_repo/b_repo/">b_repo</a></td>
  <a href="/dir1/a_repo/b_repo/atom-log" title="subscribe to repository atom feed">

Files named 'index' are not blocked

  $ get-with-headers.py localhost:$HGPORT1 'dir1/a_repo/raw-file/tip/index'
  200 Script output follows
  
  index file

Repos named 'index' take precedence over the index file

  $ get-with-headers.py localhost:$HGPORT1 'dir1/dir2/index' | grep 'index'
  <link rel="icon" href="/dir1/dir2/index/static/hgicon.png" type="image/png" />
  <meta name="robots" content="index, nofollow" />
  <link rel="stylesheet" href="/dir1/dir2/index/static/style-paper.css" type="text/css" />
  <script type="text/javascript" src="/dir1/dir2/index/static/mercurial.js"></script>
  <title>dir1/dir2/index: log</title>
     href="/dir1/dir2/index/atom-log" title="Atom feed for dir1/dir2/index" />
     href="/dir1/dir2/index/rss-log" title="RSS feed for dir1/dir2/index" />
  <img src="/dir1/dir2/index/static/hglogo.png" alt="mercurial" /></a>
  <li><a href="/dir1/dir2/index/graph/tip">graph</a></li>
  <li><a href="/dir1/dir2/index/tags">tags</a></li>
  <li><a href="/dir1/dir2/index/bookmarks">bookmarks</a></li>
  <li><a href="/dir1/dir2/index/branches">branches</a></li>
  <li><a href="/dir1/dir2/index/rev/tip">changeset</a></li>
  <li><a href="/dir1/dir2/index/file/tip">browse</a></li>
   <li><a href="/dir1/dir2/index/help">help</a></li>
  <a href="/dir1/dir2/index/atom-log" title="subscribe to atom feed">
  <img class="atom-logo" src="/dir1/dir2/index/static/feed-icon-14x14.png" alt="atom feed" />
  <h2 class="breadcrumb"><a href="/">Mercurial</a> &gt; <a href="/dir1">dir1</a> &gt; <a href="/dir1/dir2">dir2</a> &gt; <a href="/dir1/dir2/index">index</a> </h2>
  <form class="search" action="/dir1/dir2/index/log">
  number or hash, or <a href="/dir1/dir2/index/help/revsets">revset expression</a>.</div>
  <a href="/dir1/dir2/index/shortlog/tip?revcount=30">less</a>
  <a href="/dir1/dir2/index/shortlog/tip?revcount=120">more</a>
  | rev 0: <a href="/dir1/dir2/index/shortlog/39505516671b">(0)</a> <a href="/dir1/dir2/index/shortlog/tip">tip</a> 
     <a href="/dir1/dir2/index/rev/39505516671b">b</a>
  <a href="/dir1/dir2/index/shortlog/tip?revcount=30">less</a>
  <a href="/dir1/dir2/index/shortlog/tip?revcount=120">more</a>
  | rev 0: <a href="/dir1/dir2/index/shortlog/39505516671b">(0)</a> <a href="/dir1/dir2/index/shortlog/tip">tip</a> 
              '/dir1/dir2/index/shortlog/%next%',

  $ killdaemons.py

  $ cat > paths.conf << EOF
  > [paths]
  > / = $root/a
  > EOF
  $ hg serve -p $HGPORT1 -d --pid-file hg.pid --webdir-conf paths.conf
  $ cat hg.pid >> $DAEMON_PIDS

  $ hg id http://localhost:$HGPORT1
  71a89161f014

  $ get-with-headers.py localhost:$HGPORT1 '' | grep 'index'
  <meta name="robots" content="index, nofollow" />
     <a href="/rev/71a89161f014">add index file</a>

  $ killdaemons.py

paths errors 1

  $ cat error-paths-1.log

paths errors 2

  $ cat error-paths-2.log

paths errors 3

  $ cat error-paths-3.log

paths errors 4

  $ cat error-paths-4.log

paths errors 5

  $ cat error-paths-5.log

paths errors 6

  $ cat error-paths-6.log

paths errors 7

  $ cat error-paths-7.log

paths errors 8

  $ cat error-paths-8.log

paths errors 9

  $ cat error-paths-9.log

paths errors 10

  $ cat error-paths-10.log

collections errors

  $ cat error-collections.log

collections errors 2

  $ cat error-collections-2.log
