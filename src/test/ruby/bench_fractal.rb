#!/usr/local/bin/ruby

BAILOUT = 16
MAX_ITERATIONS = 1000

def fractal
  puts "Rendering"
  y = -39
  while y <= 39
    puts
    x = -39
    while x <= 39
      i = iterate(x/40.0,y/40.0)
      if (i == 0)
        print "*"
      else
        print " "
      end
      x+=1
    end
    y+=1
  end
end

def iterate(x,y)
  cr = y-0.5
  ci = x
  zi = 0.0
  zr = 0.0
  i = 0
		
  while(1)
    i += 1
    temp = zr * zi
    zr2 = zr * zr
    zi2 = zi * zi
    zr = zr2 - zi2 + cr
    zi = temp + temp + ci
    return i if (zi2 + zr2 > BAILOUT)
    return 0 if (i > MAX_ITERATIONS)
  end
end

i = 0
while i < 10
  time = Time.new
  fractal
  puts
  puts "Ruby Elapsed %f" % (Time.new - time)
  i+=1
end
