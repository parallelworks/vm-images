ignoredisk --only-use=vda
zerombr
clearpart --all --initlabel --drives=vda
reqpart
part biosboot       --fstype="biosboot" --size=1 --ondisk=vda
part /              --fstype="xfs" --ondisk=vda --size=${root_mb}${grow.root}
part /var           --fstype="xfs" --ondisk=vda --size=${var_mb}${grow.var}
part /var/log       --fstype="xfs" --ondisk=vda --size=${var_log_mb}${grow.var_log}
part /var/log/audit --fstype="xfs" --ondisk=vda --size=${var_log_audit_mb}${grow.var_log_audit}
part /var/tmp       --fstype="xfs" --ondisk=vda --size=${var_tmp_mb}${grow.var_tmp}
part /tmp           --fstype="xfs" --ondisk=vda --size=${tmp_mb}${grow.tmp}
part /home          --fstype="xfs" --ondisk=vda --size=${home_mb}${grow.home}
