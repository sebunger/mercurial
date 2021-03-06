Do not strip innocent children. See https://bitbucket.org/facebook/hg-experimental/issues/6/hg-absorb-merges-diverged-commits

  $ cat >> $HGRCPATH << EOF
  > [extensions]
  > absorb=
  > drawdag=$TESTDIR/drawdag.py
  > EOF

  $ hg init
  $ hg debugdrawdag << EOF
  > E
  > |
  > D F
  > |/
  > C
  > |
  > B
  > |
  > A
  > EOF

  $ hg up E -q
  $ echo 1 >> B
  $ echo 2 >> D
  $ hg absorb -a
  warning: orphaned descendants detected, not stripping 112478962961, 26805aba1e60
  saved backup bundle to * (glob)
  2 of 2 chunk(s) applied

  $ hg log -G -T '{desc}'
  @  E
  |
  o  D
  |
  o  C
  |
  o  B
  |
  | o  F
  | |
  | o  C
  | |
  | o  B
  |/
  o  A
  
