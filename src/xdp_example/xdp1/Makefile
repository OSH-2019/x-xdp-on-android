# SPDX-License-Identifier: GPL-2.0
# kbuild trick to avoid linker error. Can be omitted if a module is built.
obj- := dummy.o

# List of programs to build
hostprogs-y += xdp1

# Libbpf dependencies
LIBBPF := /home/gp/linux_kernel/linux-4.14.131/tools/lib/bpf.o

xdp1-objs := bpf_load.o $(LIBBPF) xdp1_user.o
# reuse xdp1 source intentionally

# Tell kbuild to always build the programs
always += xdp1_kern.o


HOSTCFLAGS += -I$(objtree)/usr/include
HOSTCFLAGS += -I$(srctree)/tools/lib/
HOSTCFLAGS += -I$(srctree)/tools/testing/selftests/bpf/
HOSTCFLAGS += -I$(srctree)/tools/lib/ -I$(srctree)/tools/include
HOSTCFLAGS += -I$(srctree)/tools/perf

HOSTCFLAGS_bpf_load.o += -I$(objtree)/usr/include -Wno-unused-variable
HOSTLOADLIBES_xdp1 += -lelf


# Allows pointing LLC/CLANG to a LLVM backend with bpf support, redefine on cmdline:
#  make samples/bpf/ LLC=~/git/llvm/build/bin/llc CLANG=~/git/llvm/build/bin/clang
LLC ?= llc
CLANG ?= clang

# Trick to allow make to be run from this directory
all: $(LIBBPF)
	$(MAKE) -C ../../ $(CURDIR)/

clean:
	$(MAKE) -C ../../ M=$(CURDIR) clean
	@rm -f *~

$(LIBBPF): FORCE
	$(MAKE) -C $(dir $@) $(notdir $@)

$(obj)/syscall_nrs.s:	$(src)/syscall_nrs.c
	$(call if_changed_dep,cc_s_c)

$(obj)/syscall_nrs.h:	$(obj)/syscall_nrs.s FORCE
	$(call filechk,offsets,__SYSCALL_NRS_H__)

clean-files += syscall_nrs.h

FORCE:


# Verify LLVM compiler tools are available and bpf target is supported by llc
.PHONY: verify_cmds verify_target_bpf $(CLANG) $(LLC)

verify_cmds: $(CLANG) $(LLC)
	@for TOOL in $^ ; do \
		if ! (which -- "$${TOOL}" > /dev/null 2>&1); then \
			echo "*** ERROR: Cannot find LLVM tool $${TOOL}" ;\
			exit 1; \
		else true; fi; \
	done

verify_target_bpf: verify_cmds
	@if ! (${LLC} -march=bpf -mattr=help > /dev/null 2>&1); then \
		echo "*** ERROR: LLVM (${LLC}) does not support 'bpf' target" ;\
		echo "   NOTICE: LLVM version >= 3.7.1 required" ;\
		exit 2; \
	else true; fi

$(src)/*.c: verify_target_bpf

$(obj)/tracex5_kern.o: $(obj)/syscall_nrs.h

# asm/sysreg.h - inline assembly used by it is incompatible with llvm.
# But, there is no easy way to fix it, so just exclude it since it is
# useless for BPF samples.
$(obj)/%.o: $(src)/%.c
	$(CLANG) $(NOSTDINC_FLAGS) $(LINUXINCLUDE) $(EXTRA_CFLAGS) -I$(obj) \
		-I$(srctree)/tools/testing/selftests/bpf/ \
		-D__KERNEL__ -D__ASM_SYSREG_H -Wno-unused-value -Wno-pointer-sign \
		-Wno-compare-distinct-pointer-types \
		-Wno-gnu-variable-sized-type-not-at-end \
		-Wno-address-of-packed-member -Wno-tautological-compare \
		-Wno-unknown-warning-option \
		-O2 -emit-llvm -c $< -o -| $(LLC) -march=bpf -filetype=obj -o $@
