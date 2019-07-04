; ModuleID = 'xdp_ddos01_blacklist_kern.c'
source_filename = "xdp_ddos01_blacklist_kern.c"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%struct.bpf_map_def = type { i32, i32, i32, i32, i32, i32, i32 }
%struct.xdp_md = type { i32, i32, i32, i32, i32 }
%struct.udphdr = type { i16, i16, i16, i16 }
%struct.tcphdr = type { i16, i16, i32, i32, i16, i16, i16, i16 }
%struct.ethhdr = type { [6 x i8], [6 x i8], i16 }
%struct.iphdr = type { i8, i8, i16, i16, i16, i8, i8, i16, i32, i32 }

@blacklist = global %struct.bpf_map_def { i32 5, i32 4, i32 8, i32 100000, i32 1, i32 0, i32 0 }, section "maps", align 4
@verdict_cnt = global %struct.bpf_map_def { i32 6, i32 4, i32 8, i32 4, i32 0, i32 0, i32 0 }, section "maps", align 4
@port_blacklist = global %struct.bpf_map_def { i32 6, i32 4, i32 4, i32 65536, i32 0, i32 0, i32 0 }, section "maps", align 4
@port_blacklist_drop_count_tcp = global %struct.bpf_map_def { i32 6, i32 4, i32 8, i32 65536, i32 0, i32 0, i32 0 }, section "maps", align 4
@port_blacklist_drop_count_udp = global %struct.bpf_map_def { i32 6, i32 4, i32 8, i32 65536, i32 0, i32 0, i32 0 }, section "maps", align 4
@_license = global [4 x i8] c"GPL\00", section "license", align 1
@llvm.used = appending global [7 x i8*] [i8* getelementptr inbounds ([4 x i8], [4 x i8]* @_license, i32 0, i32 0), i8* bitcast (%struct.bpf_map_def* @blacklist to i8*), i8* bitcast (%struct.bpf_map_def* @port_blacklist to i8*), i8* bitcast (%struct.bpf_map_def* @port_blacklist_drop_count_tcp to i8*), i8* bitcast (%struct.bpf_map_def* @port_blacklist_drop_count_udp to i8*), i8* bitcast (%struct.bpf_map_def* @verdict_cnt to i8*), i8* bitcast (i32 (%struct.xdp_md*)* @xdp_program to i8*)], section "llvm.metadata"

; Function Attrs: nounwind uwtable
define i32 @parse_port(%struct.xdp_md* nocapture readonly, i8 zeroext, i8* readonly) local_unnamed_addr #0 {
  %4 = alloca i32, align 4
  %5 = getelementptr inbounds %struct.xdp_md, %struct.xdp_md* %0, i64 0, i32 1
  %6 = load i32, i32* %5, align 4, !tbaa !2
  %7 = zext i32 %6 to i64
  %8 = bitcast i32* %4 to i8*
  call void @llvm.lifetime.start.p0i8(i64 4, i8* nonnull %8) #3
  switch i8 %1, label %48 [
    i8 17, label %9
    i8 6, label %14
  ]

; <label>:9:                                      ; preds = %3
  %10 = getelementptr inbounds i8, i8* %2, i64 8
  %11 = bitcast i8* %10 to %struct.udphdr*
  %12 = inttoptr i64 %7 to %struct.udphdr*
  %13 = icmp ugt %struct.udphdr* %11, %12
  br i1 %13, label %48, label %19

; <label>:14:                                     ; preds = %3
  %15 = getelementptr inbounds i8, i8* %2, i64 20
  %16 = bitcast i8* %15 to %struct.tcphdr*
  %17 = inttoptr i64 %7 to %struct.tcphdr*
  %18 = icmp ugt %struct.tcphdr* %16, %17
  br i1 %18, label %48, label %19

; <label>:19:                                     ; preds = %14, %9
  %20 = phi i32 [ 1, %9 ], [ 0, %14 ]
  %21 = getelementptr inbounds i8, i8* %2, i64 2
  %22 = bitcast i8* %21 to i16*
  %23 = load i16, i16* %22, align 2, !tbaa !7
  %24 = tail call i16 @llvm.bswap.i16(i16 %23) #3
  %25 = zext i16 %24 to i32
  store i32 %25, i32* %4, align 4, !tbaa !9
  %26 = call i8* inttoptr (i64 1 to i8* (i8*, i8*)*)(i8* bitcast (%struct.bpf_map_def* @port_blacklist to i8*), i8* nonnull %8) #3
  %27 = icmp eq i8* %26, null
  br i1 %27, label %48, label %28

; <label>:28:                                     ; preds = %19
  %29 = bitcast i8* %26 to i32*
  %30 = load i32, i32* %29, align 4, !tbaa !9
  %31 = shl i32 1, %20
  %32 = and i32 %30, %31
  %33 = icmp eq i32 %32, 0
  br i1 %33, label %48, label %34

; <label>:34:                                     ; preds = %28
  %35 = icmp eq i32 %20, 0
  %36 = select i1 %35, %struct.bpf_map_def* @port_blacklist_drop_count_tcp, %struct.bpf_map_def* null
  %37 = icmp eq i32 %20, 1
  %38 = select i1 %37, %struct.bpf_map_def* @port_blacklist_drop_count_udp, %struct.bpf_map_def* %36
  %39 = icmp eq %struct.bpf_map_def* %38, null
  br i1 %39, label %48, label %40

; <label>:40:                                     ; preds = %34
  %41 = bitcast %struct.bpf_map_def* %38 to i8*
  %42 = call i8* inttoptr (i64 1 to i8* (i8*, i8*)*)(i8* %41, i8* nonnull %8) #3
  %43 = bitcast i8* %42 to i32*
  %44 = icmp eq i8* %42, null
  br i1 %44, label %48, label %45

; <label>:45:                                     ; preds = %40
  %46 = load i32, i32* %43, align 4, !tbaa !9
  %47 = add i32 %46, 1
  store i32 %47, i32* %43, align 4, !tbaa !9
  br label %48

; <label>:48:                                     ; preds = %19, %28, %45, %34, %40, %3, %14, %9
  %49 = phi i32 [ 0, %9 ], [ 0, %14 ], [ 2, %3 ], [ 1, %40 ], [ 1, %34 ], [ 1, %45 ], [ 2, %28 ], [ 2, %19 ]
  call void @llvm.lifetime.end.p0i8(i64 4, i8* nonnull %8) #3
  ret i32 %49
}

; Function Attrs: argmemonly nounwind
declare void @llvm.lifetime.start.p0i8(i64, i8* nocapture) #1

; Function Attrs: argmemonly nounwind
declare void @llvm.lifetime.end.p0i8(i64, i8* nocapture) #1

; Function Attrs: nounwind uwtable
define i32 @xdp_program(%struct.xdp_md* nocapture readonly) #0 section "xdp_prog" {
  %2 = alloca i32, align 4
  %3 = alloca i32, align 4
  %4 = alloca i32, align 4
  %5 = getelementptr inbounds %struct.xdp_md, %struct.xdp_md* %0, i64 0, i32 1
  %6 = load i32, i32* %5, align 4, !tbaa !2
  %7 = zext i32 %6 to i64
  %8 = inttoptr i64 %7 to i8*
  %9 = getelementptr inbounds %struct.xdp_md, %struct.xdp_md* %0, i64 0, i32 0
  %10 = load i32, i32* %9, align 4, !tbaa !10
  %11 = zext i32 %10 to i64
  %12 = inttoptr i64 %11 to %struct.ethhdr*
  %13 = getelementptr %struct.ethhdr, %struct.ethhdr* %12, i64 0, i32 0, i64 14
  %14 = icmp ugt i8* %13, %8
  br i1 %14, label %121, label %15

; <label>:15:                                     ; preds = %1
  %16 = getelementptr inbounds %struct.ethhdr, %struct.ethhdr* %12, i64 0, i32 2
  %17 = load i16, i16* %16, align 1, !tbaa !11
  %18 = trunc i16 %17 to i8
  %19 = icmp ult i8 %18, 6
  br i1 %19, label %121, label %20, !prof !13

; <label>:20:                                     ; preds = %15
  switch i16 %17, label %28 [
    i16 129, label %21
    i16 -22392, label %21
  ]

; <label>:21:                                     ; preds = %20, %20
  %22 = getelementptr %struct.ethhdr, %struct.ethhdr* %12, i64 0, i32 0, i64 18
  %23 = icmp ugt i8* %22, %8
  br i1 %23, label %121, label %24

; <label>:24:                                     ; preds = %21
  %25 = getelementptr %struct.ethhdr, %struct.ethhdr* %12, i64 0, i32 0, i64 16
  %26 = bitcast i8* %25 to i16*
  %27 = load i16, i16* %26, align 2, !tbaa !14
  br label %28

; <label>:28:                                     ; preds = %24, %20
  %29 = phi i64 [ 14, %20 ], [ 18, %24 ]
  %30 = phi i16 [ %17, %20 ], [ %27, %24 ]
  switch i16 %30, label %40 [
    i16 129, label %31
    i16 -22392, label %31
  ]

; <label>:31:                                     ; preds = %28, %28
  %32 = add nuw nsw i64 %29, 4
  %33 = getelementptr %struct.ethhdr, %struct.ethhdr* %12, i64 0, i32 0, i64 %32
  %34 = icmp ugt i8* %33, %8
  br i1 %34, label %121, label %35

; <label>:35:                                     ; preds = %31
  %36 = getelementptr %struct.ethhdr, %struct.ethhdr* %12, i64 0, i32 0, i64 %29
  %37 = getelementptr inbounds i8, i8* %36, i64 2
  %38 = bitcast i8* %37 to i16*
  %39 = load i16, i16* %38, align 2, !tbaa !14
  br label %40

; <label>:40:                                     ; preds = %35, %28
  %41 = phi i64 [ %29, %28 ], [ %32, %35 ]
  %42 = phi i16 [ %30, %28 ], [ %39, %35 ]
  %43 = icmp eq i16 %42, 8
  br i1 %43, label %44, label %111

; <label>:44:                                     ; preds = %40
  %45 = inttoptr i64 %11 to i8*
  %46 = getelementptr i8, i8* %45, i64 %41
  %47 = bitcast i32* %3 to i8*
  call void @llvm.lifetime.start.p0i8(i64 4, i8* nonnull %47) #3
  %48 = getelementptr inbounds i8, i8* %46, i64 20
  %49 = bitcast i8* %48 to %struct.iphdr*
  %50 = inttoptr i64 %7 to %struct.iphdr*
  %51 = icmp ugt %struct.iphdr* %49, %50
  br i1 %51, label %109, label %52

; <label>:52:                                     ; preds = %44
  %53 = getelementptr inbounds i8, i8* %46, i64 12
  %54 = bitcast i8* %53 to i32*
  %55 = load i32, i32* %54, align 4, !tbaa !16
  store i32 %55, i32* %3, align 4, !tbaa !9
  %56 = call i8* inttoptr (i64 1 to i8* (i8*, i8*)*)(i8* bitcast (%struct.bpf_map_def* @blacklist to i8*), i8* nonnull %47) #3
  %57 = bitcast i8* %56 to i64*
  %58 = icmp eq i8* %56, null
  br i1 %58, label %62, label %59

; <label>:59:                                     ; preds = %52
  %60 = load i64, i64* %57, align 8, !tbaa !18
  %61 = add i64 %60, 1
  store i64 %61, i64* %57, align 8, !tbaa !18
  br label %109

; <label>:62:                                     ; preds = %52
  %63 = getelementptr inbounds i8, i8* %46, i64 9
  %64 = load i8, i8* %63, align 1, !tbaa !20
  %65 = load i32, i32* %5, align 4, !tbaa !2
  %66 = zext i32 %65 to i64
  %67 = bitcast i32* %2 to i8*
  call void @llvm.lifetime.start.p0i8(i64 4, i8* nonnull %67) #3
  switch i8 %64, label %107 [
    i8 17, label %68
    i8 6, label %73
  ]

; <label>:68:                                     ; preds = %62
  %69 = getelementptr inbounds i8, i8* %48, i64 8
  %70 = bitcast i8* %69 to %struct.udphdr*
  %71 = inttoptr i64 %66 to %struct.udphdr*
  %72 = icmp ugt %struct.udphdr* %70, %71
  br i1 %72, label %107, label %78

; <label>:73:                                     ; preds = %62
  %74 = getelementptr inbounds i8, i8* %48, i64 20
  %75 = bitcast i8* %74 to %struct.tcphdr*
  %76 = inttoptr i64 %66 to %struct.tcphdr*
  %77 = icmp ugt %struct.tcphdr* %75, %76
  br i1 %77, label %107, label %78

; <label>:78:                                     ; preds = %73, %68
  %79 = phi i32 [ 1, %68 ], [ 0, %73 ]
  %80 = getelementptr inbounds i8, i8* %48, i64 2
  %81 = bitcast i8* %80 to i16*
  %82 = load i16, i16* %81, align 2, !tbaa !7
  %83 = call i16 @llvm.bswap.i16(i16 %82) #3
  %84 = zext i16 %83 to i32
  store i32 %84, i32* %2, align 4, !tbaa !9
  %85 = call i8* inttoptr (i64 1 to i8* (i8*, i8*)*)(i8* bitcast (%struct.bpf_map_def* @port_blacklist to i8*), i8* nonnull %67) #3
  %86 = icmp eq i8* %85, null
  br i1 %86, label %107, label %87

; <label>:87:                                     ; preds = %78
  %88 = bitcast i8* %85 to i32*
  %89 = load i32, i32* %88, align 4, !tbaa !9
  %90 = shl i32 1, %79
  %91 = and i32 %89, %90
  %92 = icmp eq i32 %91, 0
  br i1 %92, label %107, label %93

; <label>:93:                                     ; preds = %87
  %94 = icmp eq i32 %79, 0
  %95 = select i1 %94, %struct.bpf_map_def* @port_blacklist_drop_count_tcp, %struct.bpf_map_def* null
  %96 = icmp eq i32 %79, 1
  %97 = select i1 %96, %struct.bpf_map_def* @port_blacklist_drop_count_udp, %struct.bpf_map_def* %95
  %98 = icmp eq %struct.bpf_map_def* %97, null
  br i1 %98, label %107, label %99

; <label>:99:                                     ; preds = %93
  %100 = bitcast %struct.bpf_map_def* %97 to i8*
  %101 = call i8* inttoptr (i64 1 to i8* (i8*, i8*)*)(i8* %100, i8* nonnull %67) #3
  %102 = bitcast i8* %101 to i32*
  %103 = icmp eq i8* %101, null
  br i1 %103, label %107, label %104

; <label>:104:                                    ; preds = %99
  %105 = load i32, i32* %102, align 4, !tbaa !9
  %106 = add i32 %105, 1
  store i32 %106, i32* %102, align 4, !tbaa !9
  br label %107

; <label>:107:                                    ; preds = %104, %99, %93, %87, %78, %73, %68, %62
  %108 = phi i32 [ 0, %68 ], [ 0, %73 ], [ 2, %62 ], [ 1, %99 ], [ 1, %93 ], [ 1, %104 ], [ 2, %87 ], [ 2, %78 ]
  call void @llvm.lifetime.end.p0i8(i64 4, i8* nonnull %67) #3
  br label %109

; <label>:109:                                    ; preds = %107, %59, %44
  %110 = phi i32 [ 1, %59 ], [ %108, %107 ], [ 0, %44 ]
  call void @llvm.lifetime.end.p0i8(i64 4, i8* nonnull %47) #3
  br label %111

; <label>:111:                                    ; preds = %109, %40
  %112 = phi i32 [ %110, %109 ], [ 2, %40 ]
  %113 = bitcast i32* %4 to i8*
  call void @llvm.lifetime.start.p0i8(i64 4, i8* nonnull %113)
  store i32 %112, i32* %4, align 4, !tbaa !9
  %114 = call i8* inttoptr (i64 1 to i8* (i8*, i8*)*)(i8* bitcast (%struct.bpf_map_def* @verdict_cnt to i8*), i8* nonnull %113) #3
  %115 = bitcast i8* %114 to i64*
  %116 = icmp eq i8* %114, null
  br i1 %116, label %120, label %117

; <label>:117:                                    ; preds = %111
  %118 = load i64, i64* %115, align 8, !tbaa !18
  %119 = add i64 %118, 1
  store i64 %119, i64* %115, align 8, !tbaa !18
  br label %120

; <label>:120:                                    ; preds = %111, %117
  call void @llvm.lifetime.end.p0i8(i64 4, i8* nonnull %113)
  br label %121

; <label>:121:                                    ; preds = %31, %21, %15, %1, %120
  %122 = phi i32 [ %112, %120 ], [ 2, %1 ], [ 2, %15 ], [ 2, %21 ], [ 2, %31 ]
  ret i32 %122
}

; Function Attrs: nounwind readnone speculatable
declare i16 @llvm.bswap.i16(i16) #2

attributes #0 = { nounwind uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { argmemonly nounwind }
attributes #2 = { nounwind readnone speculatable }
attributes #3 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{!"clang version 6.0.0-1ubuntu2 (tags/RELEASE_600/final)"}
!2 = !{!3, !4, i64 4}
!3 = !{!"xdp_md", !4, i64 0, !4, i64 4, !4, i64 8, !4, i64 12, !4, i64 16}
!4 = !{!"int", !5, i64 0}
!5 = !{!"omnipotent char", !6, i64 0}
!6 = !{!"Simple C/C++ TBAA"}
!7 = !{!8, !8, i64 0}
!8 = !{!"short", !5, i64 0}
!9 = !{!4, !4, i64 0}
!10 = !{!3, !4, i64 0}
!11 = !{!12, !8, i64 12}
!12 = !{!"ethhdr", !5, i64 0, !5, i64 6, !8, i64 12}
!13 = !{!"branch_weights", i32 1, i32 2000}
!14 = !{!15, !8, i64 2}
!15 = !{!"vlan_hdr", !8, i64 0, !8, i64 2}
!16 = !{!17, !4, i64 12}
!17 = !{!"iphdr", !5, i64 0, !5, i64 0, !5, i64 1, !8, i64 2, !8, i64 4, !8, i64 6, !5, i64 8, !5, i64 9, !8, i64 10, !4, i64 12, !4, i64 16}
!18 = !{!19, !19, i64 0}
!19 = !{!"long long", !5, i64 0}
!20 = !{!17, !5, i64 9}
