def fib(a)
  if a < 2
    a
  else
    fib(a - 1) + fib(a - 2)
  end
end

i = 0
while i < 100
  i+=1
  t = Time.now
  puts fib(40)
  puts Time.now - t
end

