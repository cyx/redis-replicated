class Redis
  class Replicated
    VERSION = "0.0.0"

    attr :all_master

    def self.connect(servers = [])
      new(servers)
    end

    def initialize(servers = [])
      @master_config = servers[0]
      @slaves_config = servers[1..-1]
    end

    def master
      @master ||= Redis.connect(@master_config)
    end

    def slave
      @slave ||= Redis.connect(@slaves_config.first)
    end
    
    def pipelined(&block)
      @all_master = true
  
      master.pipelined(&block)
    ensure
      @all_master = false
    end

    def multi(&block)
      @all_master = true

      master.multi(&block)
    ensure
      @all_master = false
    end

    def flushdb
      master.flushdb
      slave.flushdb
    end

    def no_slaves_until(countdown)
      @no_slaves_until = Time.now + countdown
    end

    def no_slaves?
      if defined?(@no_slaves_until) && @no_slaves_until
        Time.now <= @no_slaves_until
      else
        @no_slaves_until = nil
      end
    end

    def all_master?
      (defined?(@all_master) && @all_master) || no_slaves?
    end
  
    def select(db)
      master.select(db)
      slave.select(db)
    end

    WRITE_METHODS = [:append, :blpop, :brpop, :brpoplpush, :decr, :decrby, 
      :del, :discard, :expire, :expireat, :getset, :hdel, :hincrby, :hmset, 
      :hset, :hsetnx, :incr, :incrby, :linsert, :lpop, :lpush, :lpushx, :lrem,
      :lset, :ltrim, :move, :mset, :msetnx, :persist, :psubscribe, :publish, 
      :punsubscribe, :rename, :renamenx, :rpop, :rpoplpush, :rpush, :rpushx, 
      :sadd, :sdiffstore, :set, :setbit, :setex, :setnx, :setrange,
      :sinterstore, :smove, :spop, :srem, :subscribe, :sunionstore,
      :unsubscribe, :watch, :unwatch, :zadd, :zincrby, :zinterstore, :zrem,
      :zremrangebyrank, :zremrangebyscore, :zunionstore, :[]=, :mapped_mset,
      :mapped_msetnx, :mapped_hmset, :keys, :randomkey]

    READ_METHODS  = [:exists, :get, :hexists, :hget, :hgetall, :hkeys, :hlen,
      :hmget, :hvals, :lindex, :llen, :lrange, :scard, :sdiff, :sinter,
      :sismember, :smembers, :sort, :srandmember, :strlen, :substr, :sunion,
      :ttl, :type, :zcard, :zcount, :zrange, :zrangebyscore, :zrank, 
      :zrevrange, :zrevrank, :zscore, :[], :mget, :mapped_mget, :mapped_hmget,
      :dbsize]

    WRITE_METHODS.each do |meth|
      class_eval <<-DEF
        def #{meth}(*args, &bk)
          no_slaves_until(0.1)

          master.#{meth}(*args, &bk)
        end
      DEF
    end
  
    # Unfortunately for readability, define_method is significantly
    # slower than doing class_eval + def. Since we're expecting
    # thousands or more command issued against the redis client,
    # then this is really something we can't ignore.
    READ_METHODS.each do |meth|
      class_eval <<-DEF
        def #{meth}(*args, &bk)
          if all_master?
            master.#{meth}(*args, &bk)
          else
            begin
              slave.#{meth}(*args, &bk)
            rescue Exception => e
              # if e.message =~ /-ERR link with MASTER is down and slave-serve-stale-data is set to no/
                # master.#{meth}(*args, &bk)
              # else
                raise e
              # end
            end
          end
        end
      DEF
    end
  end
end
