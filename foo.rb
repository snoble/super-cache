def foo
  x = wrap([1,2,3,4,5])
  w x.map{|y| y + 1}
    .group_by{|y| y.even?}[true]
    .to_s
end

foo

x = wrap([1,2,3,4,5])
w x

w x.select {|n| n > 2}

y = x.map do |n|
  sleep(1)
  n + 3
end

y.map {|n| n*2}

z = construct do
  sleep 3
  23
end

w z + 4

# extra line
# last line
