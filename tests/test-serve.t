#require serve

  $ hgserve()
  > {
  >    hg serve -a localhost -d --pid-file=hg.pid -E errors.log -v $@ \
  >        | sed -e "s/:$HGPORT1\\([^0-9]\\)/:HGPORT1\1/g" \
  >              -e "s/:$HGPORT2\\([^0-9]\\)/:HGPORT2\1/g" \
  >              -e 's/http:\/\/[^/]*\//http:\/\/localhost\//'
  >    if [ -f hg.pid ]; then
  >        killdaemons.py hg.pid
  >    fi
  >    echo % errors
  >    cat errors.log
  > }

  $ hg init test
  $ cd test
  $ echo '[web]' > .hg/hgrc
  $ echo 'accesslog = access.log' >> .hg/hgrc
  $ echo "port = $HGPORT1" >> .hg/hgrc

Without -v

  $ hg serve -a localhost -p $HGPORT -d --pid-file=hg.pid -E errors.log
  $ cat hg.pid >> "$DAEMON_PIDS"
  $ if [ -f access.log ]; then
  >     echo 'access log created - .hg/hgrc respected'
  > fi
  access log created - .hg/hgrc respected

errors

  $ cat errors.log

With -v

  $ hgserve
  listening at http://localhost/ (bound to *$LOCALIP*:HGPORT1) (glob) (?)
  % errors

With -v and -p HGPORT2

  $ hgserve -p "$HGPORT2"
  listening at http://localhost/ (bound to *$LOCALIP*:HGPORT2) (glob) (?)
  % errors

With -v and -p daytime (should fail because low port)

#if no-root no-windows
  $ KILLQUIETLY=Y
  $ hgserve -p daytime
  abort: cannot start server at 'localhost:13': Permission denied
  abort: child process failed to start
  % errors
  $ KILLQUIETLY=N
#endif

With --prefix foo

  $ hgserve --prefix foo
  listening at http://localhost/foo/ (bound to *$LOCALIP*:HGPORT1) (glob) (?)
  % errors

With --prefix /foo

  $ hgserve --prefix /foo
  listening at http://localhost/foo/ (bound to *$LOCALIP*:HGPORT1) (glob) (?)
  % errors

With --prefix foo/

  $ hgserve --prefix foo/
  listening at http://localhost/foo/ (bound to *$LOCALIP*:HGPORT1) (glob) (?)
  % errors

With --prefix /foo/

  $ hgserve --prefix /foo/
  listening at http://localhost/foo/ (bound to *$LOCALIP*:HGPORT1) (glob) (?)
  % errors

  $ "$PYTHON" $RUNTESTDIR/killdaemons.py $DAEMON_PIDS

With out of bounds accesses

  $ rm access.log
  $ hg serve -a localhost -p $HGPORT -d --prefix some/dir \
  >    --pid-file=hg.pid -E errors.log
  $ cat hg.pid >> "$DAEMON_PIDS"

  $ hg id http://localhost:$HGPORT/some/dir7
  abort: HTTP Error 404: Not Found
  [255]
  $ hg id http://localhost:$HGPORT/some
  abort: HTTP Error 404: Not Found
  [255]

  $ cat access.log errors.log
  $LOCALIP - - [$LOGDATE$] "GET /some/dir7?cmd=capabilities HTTP/1.1" 404 - (glob)
  $LOCALIP - - [$LOGDATE$] "GET /some?cmd=capabilities HTTP/1.1" 404 - (glob)

  $ "$PYTHON" $RUNTESTDIR/killdaemons.py $DAEMON_PIDS

issue6362: Previously, this crashed on Python 3

  $ hg serve -a 0.0.0.0 -d --pid-file=hg.pid
  listening at http://*:$HGPORT1/ (bound to *:$HGPORT1) (glob) (?)

  $ cat hg.pid > "$DAEMON_PIDS"
  $ "$PYTHON" $RUNTESTDIR/killdaemons.py $DAEMON_PIDS

  $ cd ..
