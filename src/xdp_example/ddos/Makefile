TARGETS := xdp_ddos01_blacklist

CMDLINE_TOOLS := xdp_ddos01_blacklist_cmdline
COMMON_H      =  ${CMDLINE_TOOLS:_cmdline=_common.h}

TOOLS_PATH = tools

TARGETS_ALL = $(TARGETS)

KERN_SOURCES = ${TARGETS_ALL:=_kern.c}
USER_SOURCES = ${TARGETS_ALL:=_user.c}
KERN_OBJECTS = ${KERN_SOURCES:.c=.o}
USER_OBJECTS = ${USER_SOURCES:.c=.o}

CFLAGS := -g -O2 -Wall -I./kernel-usr-include/ -I$(TOOLS_PATH)/lib

LDFLAGS= -lelf

OBJECT_LOADBPF = bpf_load.o
OBJECTS = $(OBJECT_LOADBPF)

LIBBPF = $(TOOLS_PATH)/lib/bpf/libbpf.a

LLC ?= llc
CLANG ?= clang

CC = gcc

# !!!不使用内核默认include的路径
kbuilddir ?= /lib/modules/$(shell uname -r)/build/
KERNEL=$(kbuilddir)
NOSTDINC_FLAGS := -nostdinc -isystem $(shell $(CC) -print-file-name=include)

LINUXINCLUDE := -I./kernel/include
LINUXINCLUDE += -I$(KERNEL)/arch/x86/include
LINUXINCLUDE += -I$(KERNEL)/arch/x86/include/generated/uapi
LINUXINCLUDE += -I$(KERNEL)/arch/x86/include/generated
LINUXINCLUDE += -I$(KERNEL)/include
LINUXINCLUDE += -I$(KERNEL)/arch/x86/include/uapi
LINUXINCLUDE += -I$(KERNEL)/include/uapi
LINUXINCLUDE += -I$(KERNEL)/include/generated/uapi
LINUXINCLUDE += -include $(KERNEL)/include/linux/kconfig.h
EXTRA_CFLAGS=-Werror

all: dependencies $(TARGETS_ALL) $(KERN_OBJECTS) $(CMDLINE_TOOLS)

.PHONY: dependencies clean verify_cmds verify_llvm_target_bpf $(CLANG) $(LLC)

# Manually define dependencies to e.g. include files
napi_monitor:        napi_monitor.h
napi_monitor_kern.o: napi_monitor.h

clean:
	@find . -type f \
		\( -name '*~' \
		-o -name '*.ll' \
		-o -name '*.bc' \
		-o -name 'core' \) \
		-exec rm -vf '{}' \;
	rm -f $(OBJECTS)
	rm -f $(TARGETS_ALL)
	rm -f $(KERN_OBJECTS)
	rm -f $(USER_OBJECTS)
	make -C $(TOOLS_PATH)/lib/bpf clean

dependencies: verify_llvm_target_bpf linux-src-devel-headers

linux-src:
	@if ! test -d $(KERNEL)/; then \
		echo "ERROR: Need kernel source code to compile against" ;\
		echo "(Cannot open directory: $(KERNEL))" ;\
		exit 1; \
	else true; fi

linux-src-libbpf: linux-src
	@if ! test -d $(KERNEL)/tools/lib/bpf/; then \
		echo "WARNING: Compile against local kernel source code copy" ;\
		echo "       and specifically tools/lib/bpf/ "; \
	else true; fi

linux-src-devel-headers: linux-src-libbpf
	@if ! test -d $(KERNEL)/usr/include/ ; then \
		echo -n "WARNING: Need kernel source devel headers"; \
		echo    " likely need to run:"; \
		echo "       (in kernel source dir: $(KERNEL))"; \
		echo -e "\n  make headers_install\n"; \
		true ; \
	else true; fi

verify_cmds: $(CLANG) $(LLC)
	@for TOOL in $^ ; do \
		if ! (which -- "$${TOOL}" > /dev/null 2>&1); then \
			echo "*** ERROR: Cannot find LLVM tool $${TOOL}" ;\
			exit 1; \
		else true; fi; \
	done

verify_llvm_target_bpf: verify_cmds
	@if ! (${LLC} -march=bpf -mattr=help > /dev/null 2>&1); then \
		echo "*** ERROR: LLVM (${LLC}) does not support 'bpf' target" ;\
		echo "   NOTICE: LLVM version >= 3.7.1 required" ;\
		exit 2; \
	else true; fi

# 
$(OBJECT_LOADBPF): bpf_load.c bpf_load.h
	$(CC) $(CFLAGS) -o $@ -c $<

LIBBPF_SOURCES  = $(TOOLS_PATH)/lib/bpf/*.c

# New ELF-loaded avail in libbpf (in bpf/libbpf.c)
$(LIBBPF): $(LIBBPF_SOURCES) $(TOOLS_PATH)/lib/bpf/Makefile
	make -C $(TOOLS_PATH)/lib/bpf/ all

$(KERN_OBJECTS): %.o: %.c bpf_helpers.h Makefile
	$(CLANG) -S $(NOSTDINC_FLAGS) $(LINUXINCLUDE) $(EXTRA_CFLAGS) \
	    -D__KERNEL__ -D__ASM_SYSREG_H \
	    -D__BPF_TRACING__ \
	    -Wall \
	    -Wno-unused-value -Wno-pointer-sign \
	    -D__TARGET_ARCH_$(ARCH) \
	    -Wno-compare-distinct-pointer-types \
	    -Wno-gnu-variable-sized-type-not-at-end \
	    -Wno-tautological-compare \
	    -Wno-unknown-warning-option \
	    -Wno-address-of-packed-member \
	    -O2 -emit-llvm -c $< -o ${@:.o=.ll}
	$(LLC) -march=bpf -filetype=obj -o $@ ${@:.o=.ll}

$(TARGETS): %: %_user.c $(OBJECTS) $(LIBBPF) Makefile bpf_util.h
	$(CC) $(CFLAGS) $(OBJECTS) $(LDFLAGS) -o $@ $<  $(LIBBPF)

$(CMDLINE_TOOLS): %: %.c $(OBJECTS) $(LIBBPF) Makefile $(COMMON_H) bpf_util.h
	$(CC) -g $(CFLAGS) $(OBJECTS) $(LDFLAGS) -o $@ $<  $(LIBBPF)
