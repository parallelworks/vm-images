# VM Base Images

Rocky Linux 9 x86_64 base images with separate partitions, built from the official minimal ISO with Packer, QEMU and a kickstart per cloud. Each build produces one disk image you can import into AWS, Azure, Google Cloud or Oracle Cloud.

| Cloud | Output | Notes |
| --- | --- | --- |
| aws | dynamic VHD | cloud-init, xen drivers in initramfs, Amazon Time Sync |
| azure | fixed VHD, 1 MiB aligned | WALinuxAgent with cloud-init provisioning, Hyper-V drivers |
| google | dynamic VHD | cloud-init only, no Google guest agent |
| oracle | qcow2 | virtio drivers in initramfs, GRUB on the serial console |

The disk is GPT and boots with UEFI only, so import it as a UEFI or Generation 2 image.

## Partition layout

| Mount | Default size (GiB) | Workflow input |
| --- | --- | --- |
| `/boot/efi` | 0.6 | fixed |
| `/` | 50 | `root_gb` |
| `/var` | 15 | `var_gb` |
| `/var/log` | 8 | `var_log_gb` |
| `/var/log/audit` | 3 | `var_log_audit_gb` |
| `/var/tmp` | 5 | `var_tmp_gb` |
| `/tmp` | 8 | `tmp_gb` |
| `/home` | 29 | `home_gb` |

The disk size is the sum of the partitions plus 1 GiB for the EFI system partition, so the defaults give a 119 GiB disk that fits a 120 GB cloud volume. `grow_partition` picks the partition that is placed last on the disk, so it is the one you can grow after launch. It defaults to `home` and can be any of `root`, `var`, `var_log`, `var_log_audit`, `var_tmp`, `tmp` or `home`. Every partition is XFS and there is no LVM or swap. `/boot` lives on `/`.

### Grow the partition after launch

When you launch the image on a volume larger than the image, the extra space sits unallocated at the end of the disk. Only the last partition can use it, and nothing grows it automatically. Grow it by hand with `growpart`, which every image includes. Set `mount` to the mount point of the partition you picked with `grow_partition`:

```bash
mount=/home
src=$(findmnt -no SOURCE "$mount")
disk=/dev/$(lsblk -no PKNAME "$src")
part=$(cat "/sys/class/block/$(basename "$src")/partition")
sudo growpart "$disk" "$part"
sudo xfs_growfs "$mount"
df -h "$mount"
```

The filesystem stays mounted the whole time, so no reboot is needed.

## Build in GitHub Actions

Run the **Build Rocky 9 base image** workflow from the Actions tab, or from the CLI:

```bash
gh workflow run build-rocky9.yml -R parallelworks/vm-images \
  -f cloud=aws -f grow_partition=home -f root_gb=50 -f var_gb=15 \
  -f var_log_gb=8 -f var_log_audit_gb=3 -f var_tmp_gb=5 -f tmp_gb=8 -f home_gb=29
```

Pick `cloud=all` to build all four clouds in parallel. Builds run on `ubuntu-24.04` hosted runners with KVM and take about 20 to 30 minutes. If a runner has no `/dev/kvm`, the job warns and falls back to software emulation, which takes 2 to 4 hours.

Each job uploads two artifacts:

- `rocky9-separate-partitions-<cloud>-x86_64-<run number>` holds the zstd-compressed image and `SHA256SUMS`.
- `logs-<cloud>-<run number>` holds the installer serial console log and the Packer debug log.

Download and unpack an image:

```bash
gh run download <run id> -R parallelworks/vm-images -n rocky9-separate-partitions-aws-x86_64-<run number>
zstd -d rocky9-separate-partitions-aws-x86_64.vhd.zst
sha256sum -c SHA256SUMS
```

`zstd -d` writes the image back as a sparse file, so a 119 GiB fixed VHD only uses a few GB on disk.

Every pull request runs `packer fmt`, `packer validate` for each cloud, and `shellcheck`.

## Build locally

Linux with KVM:

```bash
sudo apt-get install -y qemu-system-x86 qemu-utils ovmf
packer init rocky-9/
packer build -var cloud=aws -var root_gb=40 -var grow_partition=root rocky-9/
```

macOS on Apple Silicon has to emulate x86_64, so expect a few hours:

```bash
brew install qemu packer
packer init rocky-9/
packer build -var cloud=aws -var accelerator=tcg \
  -var efi_firmware_code=/opt/homebrew/share/qemu/edk2-x86_64-code.fd \
  -var efi_firmware_vars=/opt/homebrew/share/qemu/edk2-i386-vars.fd \
  rocky-9/
```

On an Intel Mac use `-var accelerator=hvf` instead.

The image lands in `output-rocky9/` and the installer console log in `serial.log`. Run `scripts/check-sizes.sh` with the `ROOT_GB`, `VAR_GB`, `VAR_LOG_GB`, `VAR_LOG_AUDIT_GB`, `VAR_TMP_GB`, `TMP_GB`, `HOME_GB` and `GROW_PARTITION` environment variables to check a layout and see the resulting disk size before a long build.

When Rocky 9.9 ships, the 9.8 ISO moves to `https://dl.rockylinux.org/vault/rocky/9.8/isos/x86_64/`. Pass `-var iso_url=...` and `-var iso_checksum=sha256:...` to point at a different ISO. Packages always come from the latest Rocky 9 repositories regardless of the ISO.

## Import into a cloud

### AWS

```bash
aws s3 cp rocky9-separate-partitions-aws-x86_64.vhd s3://<bucket>/
aws ec2 import-snapshot --disk-container \
  "Format=VHD,UserBucket={S3Bucket=<bucket>,S3Key=rocky9-separate-partitions-aws-x86_64.vhd}"
aws ec2 describe-import-snapshot-tasks --import-task-ids <import task id>
aws ec2 register-image --name rocky9-separate-partitions \
  --architecture x86_64 --virtualization-type hvm --ena-support --boot-mode uefi \
  --root-device-name /dev/xvda \
  --block-device-mappings "DeviceName=/dev/xvda,Ebs={SnapshotId=<snapshot id>,VolumeType=gp3}"
```

### Azure

Upload as a page blob so `azcopy` skips the empty regions of the fixed VHD, then create a Generation 2 image:

```bash
azcopy copy rocky9-separate-partitions-azure-x86_64.vhd \
  "https://<account>.blob.core.windows.net/<container>/rocky9.vhd?<SAS>" --blob-type PageBlob
az image create -g <resource group> -n rocky9-separate-partitions \
  --os-type Linux --hyper-v-generation V2 \
  --source "https://<account>.blob.core.windows.net/<container>/rocky9.vhd"
```

### Google Cloud

Google creates images from a raw disk in a tarball:

```bash
qemu-img convert -f vpc -O raw rocky9-separate-partitions-google-x86_64.vhd disk.raw
tar --format=oldgnu -Sczf rocky9.tar.gz disk.raw
gcloud storage cp rocky9.tar.gz gs://<bucket>/
gcloud compute images create rocky9-separate-partitions \
  --source-uri gs://<bucket>/rocky9.tar.gz --guest-os-features UEFI_COMPATIBLE
```

### Oracle Cloud

Upload the qcow2 to Object Storage, then:

```bash
oci compute image import from-object -c <compartment ocid> \
  --namespace <namespace> --bucket-name <bucket> \
  --name rocky9-separate-partitions-oracle-x86_64.qcow2 \
  --display-name rocky9-separate-partitions \
  --source-image-type QCOW2 --launch-mode PARAVIRTUALIZED
```

Once the import finishes, open the image's **Edit image capabilities** page and make sure **Firmware** is `UEFI_64` only. An instance launched with `BIOS` firmware will not boot.

## Layout of this repo

| Path | Purpose |
| --- | --- |
| `rocky-9/rocky9.pkr.hcl` | Packer QEMU build and all variables |
| `rocky-9/partitions.pkrtpl.hcl` | Partition block shared by every kickstart |
| `rocky-9/http/ks-<cloud>.cfg.pkrtpl.hcl` | Per-cloud kickstart templates |
| `scripts/check-sizes.sh` | Checks that the partitions fit the disk |
| `scripts/convert-image.sh` | Converts the raw disk to VHD or qcow2 and writes `SHA256SUMS` |
| `.github/workflows/build-rocky9.yml` | Manual build workflow |
| `.github/workflows/validate.yml` | Pull request checks |

In the kickstart templates, write `$${` and `%%{` wherever the rendered kickstart needs a literal `${` or `%{`.
