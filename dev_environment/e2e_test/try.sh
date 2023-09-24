#bash /home/a0p0ie5.linux/go/bin/script.sh
before_rl_drop_count=`curl -sS localhost:8898/metrics | grep rl_drop_count_map_0_scalar | awk '{print $NF}'`
before_rl_recv_count=`curl -sS localhost:8898/metrics | grep rl_recv_count_map_0_max-rate | awk '{print $NF}'`
before_cl_recv_count=`curl -sS localhost:8898/metrics | grep cl_recv_count_map_0_scalar | awk '{print $NF}'`
hey -n 200 -c 20 http://localhost:8080 > /dev/null
#sleep 5
after_rl_drop_count=`curl -sS localhost:8898/metrics | grep rl_drop_count_map_0_scalar | awk '{print $NF}'`
after_rl_recv_count=`curl -sS localhost:8898/metrics | grep rl_recv_count_map_0_max-rate | awk '{print $NF}'`
after_cl_recv_count=`curl -sS localhost:8898/metrics | grep cl_recv_count_map_0_scalar | awk '{print $NF}'`

if [ $(expr $after_rl_drop_count - $before_rl_drop_count) -ne 0 ]
then
  echo "rl_drop_count changed"
fi

if [ $(expr $after_rl_recv_count - $before_rl_recv_count) -ne 0 ]
then
  echo "rl_recv_count changed"
fi

if [ $(expr $after_cl_recv_count - $before_cl_recv_count) -eq 2 ]
then
  echo "cl_recv_count is good"
fi

#bash /home/a0p0ie5.linux/go/bin/clean.sh
