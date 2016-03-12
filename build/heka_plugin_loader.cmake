add_external_plugin(git https://github.com/Clever/heka-clever-plugins f49db82bf88e021bcfa7729c52cc48937a5ecc83)

# Dependencies for heka-clever-plugins
git_clone(https://github.com/aws/aws-sdk-go v0.9.17)
add_dependencies(heka-clever-plugins aws-sdk-go)
git_clone(https://github.com/vaughan0/go-ini a98ad7ee00ec53921f08832bc06ecf7fd600e6a1)
add_dependencies(heka-clever-plugins go-ini)
git_clone(https://github.com/golang/mock bd3c8e81be01eef76d4b503f5e687d2d1354d2d9)
add_dependencies(heka-clever-plugins mock)
git_clone(https://github.com/jmespath/go-jmespath 0.2.2)
add_dependencies(heka-clever-plugins go-jmespath)
git_clone(https://github.com/lib/pq 165a3529e799da61ab10faed1fabff3662d6193f)
add_dependencies(heka-clever-plugins pq)
