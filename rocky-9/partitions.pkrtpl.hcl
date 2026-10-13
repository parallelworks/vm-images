ignoredisk --only-use=vda
zerombr
clearpart --all --initlabel --drives=vda
reqpart
part biosboot       --fstype="biosboot" --size=1 --ondisk=vda
part /              --fstype="xfs" --ondisk=vda --size=${root_mb}
part /var           --fstype="xfs" --ondisk=vda --size=${var_mb}
part /var/log       --fstype="xfs" --ondisk=vda --size=${var_log_mb}
part /var/log/audit --fstype="xfs" --ondisk=vda --size=${var_log_audit_mb}
part /var/tmp       --fstype="xfs" --ondisk=vda --size=${var_tmp_mb}
part /tmp           --fstype="xfs" --ondisk=vda --size=${tmp_mb}
part /home          --fstype="xfs" --ondisk=vda --size=1 --grow
