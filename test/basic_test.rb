require File.expand_path("helper", File.dirname(__FILE__))

setup do
  init(Redis::Replicated.connect([OPTIONS, SOPTIONS]))
end

test "configuration" do |rr|
  master = %r{connected to redis://127.0.0.1:6379/15}
  assert(rr.master.inspect =~ master)

  slave = %r{connected to redis://127.0.0.1:6380/15}
  assert(rr.slave.inspect =~ slave)
end

test "set / get" do |rr|
  rr.set "foo", "bar"
  sleep 2
  assert_equal "bar", rr.get("foo")
end

test "set / get a thousand keys" do |rr|
  100.times do |i|
    rr.set "foo#{i}", "bar#{i}"
  end

  100.times do |i|
    assert_equal "bar#{i}", rr.get("foo#{i}")
  end
end

test "pipelined commands" do |rr|
  # Since there is no sane way of testing this to my knowledge,
  # verification should happen by doing a redis-cli for both 6379 and 6380
  # servers, and running monitor.
  #
  # All pipelined commands should happen on master.
  rr.pipelined do
    10.times do |i| 
      rr.set "foo#{i}", "bar#{i}"
      rr.get "foo#{i}"
    end
  end

  10.times do |i|
    assert_equal "bar#{i}", rr.get("foo#{i}")
  end
end

test "multi-exec" do |rr|
  # Since there is no sane way of testing this to my knowledge,
  # verification should happen by doing a redis-cli for both 6379 and 6380
  # servers, and running monitor.
  #
  # All commands within the multi block should happen on master.
  rr.multi do
    rr.set "foo", "bar"
    rr.del "foo"
    rr.get "foo"
  end

  assert_equal nil, rr.get("foo")
end
