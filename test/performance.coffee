rmutt = require '..'

describe 'performance', ->

  it 'parse nested parens', ->
    @timeout 100
    source = """
      a:(((((((b)))))));
    """
    rmutt.compile source

  it 'parse this rule from math.rm', ->
    @timeout 1000
    source = """
      add[a,b]:
        zupfx[
         (sum="NaN")
         (ignore=a>"0"%(^sum=b))
         (ignore=b>"0"%(^sum=a))
         (sum>"NaN"%(
           (l = add_d[lsd[a],lsd[b]])
           (m=add[zpfx[msds[a]],zpfx[msds[b]]])
           (ignore=(msds[l] > "1" % ((^m=inc[m]) (^l=l > /1(.)/\\1/))))
           m l))
        ];
    """
    rmutt.compile source
