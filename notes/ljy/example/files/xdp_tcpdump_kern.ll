; ModuleID = 'xdp_tcpdump_kern.c'
source_filename = "xdp_tcpdump_kern.c"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%struct.bpf_map_def = type { i32, i32, i32, i32, i32, i32, i32 }
%struct.xdp_md = type { i32, i32, i32, i32, i32 }
%struct.my_perf_hdr = type { i16, i16 }

@perf_ring_map = global %struct.bpf_map_def { i32 4, i32 4, i32 4, i32 128, i32 0, i32 0, i32 0 }, section "maps", align 4
@_license = global [4 x i8] c"GPL\00", section "license", align 1
@llvm.used = appending global [3 x i8*] [i8* getelementptr inbounds ([4 x i8], [4 x i8]* @_license, i32 0, i32 0), i8* bitcast (i32 (%struct.xdp_md*)* @_xdp_prog0 to i8*), i8* bitcast (%struct.bpf_map_def* @perf_ring_map to i8*)], section "llvm.metadata"

; Function Attrs: nounwind uwtable
define i32 @_xdp_prog0(%struct.xdp_md*) #0 section "xdp_tcpdump_to_perf_ring" {
  %2 = alloca %struct.my_perf_hdr, align 2
  %3 = getelementptr inbounds %struct.xdp_md, %struct.xdp_md* %0, i64 0, i32 1
  %4 = load i32, i32* %3, align 4, !tbaa !2
  %5 = zext i32 %4 to i64
  %6 = inttoptr i64 %5 to i8*
  %7 = getelementptr inbounds %struct.xdp_md, %struct.xdp_md* %0, i64 0, i32 0
  %8 = load i32, i32* %7, align 4, !tbaa !7
  %9 = zext i32 %8 to i64
  %10 = inttoptr i64 %9 to i8*
  %11 = bitcast %struct.my_perf_hdr* %2 to i8*
  call void @llvm.lifetime.start.p0i8(i64 4, i8* nonnull %11) #2
  %12 = icmp ult i8* %10, %6
  br i1 %12, label %13, label %23

; <label>:13:                                     ; preds = %1
  %14 = getelementptr inbounds %struct.my_perf_hdr, %struct.my_perf_hdr* %2, i64 0, i32 0
  store i16 -25431, i16* %14, align 2, !tbaa !8
  %15 = sub nsw i64 %5, %9
  %16 = trunc i64 %15 to i16
  %17 = getelementptr inbounds %struct.my_perf_hdr, %struct.my_perf_hdr* %2, i64 0, i32 1
  store i16 %16, i16* %17, align 2, !tbaa !11
  %18 = shl i64 %15, 32
  %19 = and i64 %18, 281470681743360
  %20 = or i64 %19, 4294967295
  %21 = bitcast %struct.xdp_md* %0 to i8*
  %22 = call i32 inttoptr (i64 25 to i32 (i8*, i8*, i64, i8*, i32)*)(i8* %21, i8* bitcast (%struct.bpf_map_def* @perf_ring_map to i8*), i64 %20, i8* nonnull %11, i32 4) #2
  br label %23

; <label>:23:                                     ; preds = %13, %1
  call void @llvm.lifetime.end.p0i8(i64 4, i8* nonnull %11) #2
  ret i32 2
}

; Function Attrs: argmemonly nounwind
declare void @llvm.lifetime.start.p0i8(i64, i8* nocapture) #1

; Function Attrs: argmemonly nounwind
declare void @llvm.lifetime.end.p0i8(i64, i8* nocapture) #1

attributes #0 = { nounwind uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { argmemonly nounwind }
attributes #2 = { nounwind }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{!"clang version 6.0.0-1ubuntu2 (tags/RELEASE_600/final)"}
!2 = !{!3, !4, i64 4}
!3 = !{!"xdp_md", !4, i64 0, !4, i64 4, !4, i64 8, !4, i64 12, !4, i64 16}
!4 = !{!"int", !5, i64 0}
!5 = !{!"omnipotent char", !6, i64 0}
!6 = !{!"Simple C/C++ TBAA"}
!7 = !{!3, !4, i64 0}
!8 = !{!9, !10, i64 0}
!9 = !{!"my_perf_hdr", !10, i64 0, !10, i64 2}
!10 = !{!"short", !5, i64 0}
!11 = !{!9, !10, i64 2}
