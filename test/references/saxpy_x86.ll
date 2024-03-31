; Function Attrs: uwtable                                  ┃ ; Function Attrs: uwtable                                 
define void @saxpy({}* noundef nonnull align 16 dereferen…⟪╋⟫define void @saxpy_simd({}* noundef nonnull align 16 dere…
top:                                                       ┃ top:                                                      
  %4 = bitcast {}* %0 to { i8*, i64, i16, i16, i32 }*      ┃   %4 = bitcast {}* %0 to { i8*, i64, i16, i16, i32 }*     
  %arraylen_ptr = getelementptr inbounds { i8*, i64, i16,… ┃   %arraylen_ptr = getelementptr inbounds { i8*, i64, i16,…
  %arraylen = load i64, i64* %arraylen_ptr, align 8        ┃   %arraylen = load i64, i64* %arraylen_ptr, align 8       
  %.not.not = icmp eq i64 %arraylen, 0                    ⟪╋⟫  %.not = icmp eq i64 %arraylen, 0                        
  br i1 %.not.not, label %L31, label %L13.preheader       ⟪╋⟫  br i1 %.not, label %L32, label %L12.lr.ph               
                                                          ⟪┫                                                           
L13.preheader:                                    ; preds…⟪┫                                                           
  %5 = bitcast {}* %2 to { i8*, i64, i16, i16, i32 }*     ⟪┫                                                           
  %arraylen_ptr5 = getelementptr inbounds { i8*, i64, i16…⟪┫                                                           
  %arraylen6 = load i64, i64* %arraylen_ptr5, align 8     ⟪┫                                                           
  %6 = bitcast {}* %3 to { i8*, i64, i16, i16, i32 }*     ⟪┫                                                           
  %arraylen_ptr7 = getelementptr inbounds { i8*, i64, i16…⟪┫                                                           
  %arraylen8 = load i64, i64* %arraylen_ptr7, align 8     ⟪┫                                                           
  %7 = bitcast {}* %2 to i64**                            ⟪┫                                                           
  %arrayptr29 = load i64*, i64** %7, align 8              ⟪┫                                                           
  %8 = bitcast {}* %3 to i64**                            ⟪┫                                                           
  %arrayptr1430 = load i64*, i64** %8, align 8            ⟪┫                                                           
  %9 = bitcast {}* %0 to i64**                            ⟪┫                                                           
  %arrayptr2331 = load i64*, i64** %9, align 8            ⟪┫                                                           
  %umin = call i64 @llvm.umin.i64(i64 %arraylen6, i64 %ar…⟪┫                                                           
  %smin = call i64 @llvm.smin.i64(i64 %arraylen8, i64 0)  ⟪┫                                                           
  %10 = sub i64 %arraylen8, %smin                         ⟪┫                                                           
  %smax = call i64 @llvm.smax.i64(i64 %smin, i64 -1)      ⟪┫                                                           
  %11 = add nsw i64 %smax, 1                              ⟪┫                                                           
  %12 = mul nuw nsw i64 %10, %11                          ⟪┫                                                           
  %umin36 = call i64 @llvm.umin.i64(i64 %umin, i64 %12)   ⟪┫                                                           
  %exit.mainloop.at = call i64 @llvm.umin.i64(i64 %umin36…⟪┫                                                           
  %.not = icmp eq i64 %exit.mainloop.at, 0                ⟪┫                                                           
  br i1 %.not, label %main.pseudo.exit, label %idxend21.p…⟪┫                                                           
                                                          ⟪┫                                                           
idxend21.preheader:                               ; preds…⟪┫                                                           
  %min.iters.check = icmp ult i64 %exit.mainloop.at, 16   ⟪┫                                                           
  br i1 %min.iters.check, label %scalar.ph, label %vector…⟪┫                                                           
                                                           ┃                                                           
vector.memcheck:                                  ; preds…⟪┫                                                           
  %scevgep = getelementptr i64, i64* %arrayptr2331, i64 %…⟪┫                                                           
  %scevgep58 = getelementptr i64, i64* %arrayptr29, i64 %…⟪┫                                                           
  %scevgep61 = getelementptr i64, i64* %arrayptr1430, i64…⟪┫                                                           
  %bound0 = icmp ult i64* %arrayptr2331, %scevgep58       ⟪┫                                                           
  %bound1 = icmp ult i64* %arrayptr29, %scevgep           ⟪┫                                                           
  %found.conflict = and i1 %bound0, %bound1               ⟪┫                                                           
  %bound063 = icmp ult i64* %arrayptr2331, %scevgep61     ⟪┫                                                           
  %bound164 = icmp ult i64* %arrayptr1430, %scevgep       ⟪┫                                                           
  %found.conflict65 = and i1 %bound063, %bound164         ⟪┫                                                           
  %conflict.rdx = or i1 %found.conflict, %found.conflict6…⟪┫                                                           
  br i1 %conflict.rdx, label %scalar.ph, label %vector.ph ⟪╋⟫  br i1 %min.iters.check, label %scalar.ph, label %vector…
                                                           ┣⟫L12.lr.ph:                                        ; preds…
                                                           ┣⟫  %5 = bitcast {}* %2 to i64**                            
                                                           ┣⟫  %arrayptr8 = load i64*, i64** %5, align 8               
                                                           ┣⟫  %6 = bitcast {}* %3 to i64**                            
                                                           ┣⟫  %arrayptr29 = load i64*, i64** %6, align 8              
                                                           ┣⟫  %7 = bitcast {}* %0 to i64**                            
                                                           ┣⟫  %arrayptr510 = load i64*, i64** %7, align 8             
                                                           ┣⟫  %min.iters.check = icmp ult i64 %arraylen, 16           
                                                           ┃                                                           
vector.ph:                                        ; preds…⟪╋⟫vector.ph:                                        ; preds…
  %n.vec = and i64 %exit.mainloop.at, 9223372036854775792 ⟪╋⟫  %n.vec = and i64 %arraylen, 9223372036854775792         
  %ind.end = or i64 %n.vec, 1                             ⟪┫                                                           
  %broadcast.splatinsert = insertelement <4 x i64> poison… ┃   %broadcast.splatinsert = insertelement <4 x i64> poison…
  %broadcast.splat = shufflevector <4 x i64> %broadcast.s… ┃   %broadcast.splat = shufflevector <4 x i64> %broadcast.s…
  %13 = add nsw i64 %n.vec, -16                           ⟪╋⟫  %8 = add nsw i64 %n.vec, -16                            
  %14 = lshr exact i64 %13, 4                             ⟪╋⟫  %9 = lshr exact i64 %8, 4                               
  %15 = add nuw nsw i64 %14, 1                            ⟪╋⟫  %10 = add nuw nsw i64 %9, 1                             
  %xtraiter = and i64 %15, 1                              ⟪╋⟫  %xtraiter = and i64 %10, 1                              
  %16 = icmp eq i64 %13, 0                                ⟪╋⟫  %11 = icmp eq i64 %8, 0                                 
  br i1 %16, label %middle.block.unr-lcssa, label %vector…⟪╋⟫  br i1 %11, label %middle.block.unr-lcssa, label %vector…
                                                           ┃                                                           
vector.ph.new:                                    ; preds… ┃ vector.ph.new:                                    ; preds…
  %unroll_iter = and i64 %15, 2305843009213693950         ⟪╋⟫  %unroll_iter = and i64 %10, 2305843009213693950         
  br label %vector.body                                    ┃   br label %vector.body                                   
                                                           ┃                                                           
vector.body:                                      ; preds… ┃ vector.body:                                      ; preds…
  %index = phi i64 [ 0, %vector.ph.new ], [ %index.next.1… ┃   %index = phi i64 [ 0, %vector.ph.new ], [ %index.next.1…
  %niter = phi i64 [ 0, %vector.ph.new ], [ %niter.next.1… ┃   %niter = phi i64 [ 0, %vector.ph.new ], [ %niter.next.1…
  %17 = getelementptr inbounds i64, i64* %arrayptr29, i64…⟪╋⟫  %12 = getelementptr inbounds i64, i64* %arrayptr8, i64 …
  %18 = bitcast i64* %17 to <4 x i64>*                    ⟪╋⟫  %13 = bitcast i64* %12 to <4 x i64>*                    
  %wide.load = load <4 x i64>, <4 x i64>* %18, align 8    ⟪╋⟫  %wide.load = load <4 x i64>, <4 x i64>* %13, align 8    
  %19 = getelementptr inbounds i64, i64* %17, i64 4       ⟪╋⟫  %14 = getelementptr inbounds i64, i64* %12, i64 4       
  %20 = bitcast i64* %19 to <4 x i64>*                    ⟪╋⟫  %15 = bitcast i64* %14 to <4 x i64>*                    
  %wide.load66 = load <4 x i64>, <4 x i64>* %20, align 8  ⟪╋⟫  %wide.load13 = load <4 x i64>, <4 x i64>* %15, align 8  
  %21 = getelementptr inbounds i64, i64* %17, i64 8       ⟪╋⟫  %16 = getelementptr inbounds i64, i64* %12, i64 8       
  %22 = bitcast i64* %21 to <4 x i64>*                    ⟪╋⟫  %17 = bitcast i64* %16 to <4 x i64>*                    
  %wide.load67 = load <4 x i64>, <4 x i64>* %22, align 8  ⟪╋⟫  %wide.load14 = load <4 x i64>, <4 x i64>* %17, align 8  
  %23 = getelementptr inbounds i64, i64* %17, i64 12      ⟪╋⟫  %18 = getelementptr inbounds i64, i64* %12, i64 12      
  %24 = bitcast i64* %23 to <4 x i64>*                    ⟪╋⟫  %19 = bitcast i64* %18 to <4 x i64>*                    
  %wide.load68 = load <4 x i64>, <4 x i64>* %24, align 8  ⟪╋⟫  %wide.load15 = load <4 x i64>, <4 x i64>* %19, align 8  
  %25 = mul <4 x i64> %wide.load, %broadcast.splat        ⟪╋⟫  %20 = mul <4 x i64> %wide.load, %broadcast.splat        
  %26 = mul <4 x i64> %wide.load66, %broadcast.splat      ⟪╋⟫  %21 = mul <4 x i64> %wide.load13, %broadcast.splat      
  %27 = mul <4 x i64> %wide.load67, %broadcast.splat      ⟪╋⟫  %22 = mul <4 x i64> %wide.load14, %broadcast.splat      
  %28 = mul <4 x i64> %wide.load68, %broadcast.splat      ⟪╋⟫  %23 = mul <4 x i64> %wide.load15, %broadcast.splat      
  %29 = getelementptr inbounds i64, i64* %arrayptr1430, i…⟪╋⟫  %24 = getelementptr inbounds i64, i64* %arrayptr29, i64…
  %30 = bitcast i64* %29 to <4 x i64>*                    ⟪╋⟫  %25 = bitcast i64* %24 to <4 x i64>*                    
  %wide.load75 = load <4 x i64>, <4 x i64>* %30, align 8  ⟪╋⟫  %wide.load22 = load <4 x i64>, <4 x i64>* %25, align 8  
  %31 = getelementptr inbounds i64, i64* %29, i64 4       ⟪╋⟫  %26 = getelementptr inbounds i64, i64* %24, i64 4       
  %32 = bitcast i64* %31 to <4 x i64>*                    ⟪╋⟫  %27 = bitcast i64* %26 to <4 x i64>*                    
  %wide.load76 = load <4 x i64>, <4 x i64>* %32, align 8  ⟪╋⟫  %wide.load23 = load <4 x i64>, <4 x i64>* %27, align 8  
  %33 = getelementptr inbounds i64, i64* %29, i64 8       ⟪╋⟫  %28 = getelementptr inbounds i64, i64* %24, i64 8       
  %34 = bitcast i64* %33 to <4 x i64>*                    ⟪╋⟫  %29 = bitcast i64* %28 to <4 x i64>*                    
  %wide.load77 = load <4 x i64>, <4 x i64>* %34, align 8  ⟪╋⟫  %wide.load24 = load <4 x i64>, <4 x i64>* %29, align 8  
  %35 = getelementptr inbounds i64, i64* %29, i64 12      ⟪╋⟫  %30 = getelementptr inbounds i64, i64* %24, i64 12      
  %36 = bitcast i64* %35 to <4 x i64>*                    ⟪╋⟫  %31 = bitcast i64* %30 to <4 x i64>*                    
  %wide.load78 = load <4 x i64>, <4 x i64>* %36, align 8  ⟪╋⟫  %wide.load25 = load <4 x i64>, <4 x i64>* %31, align 8  
  %37 = add <4 x i64> %wide.load75, %25                   ⟪╋⟫  %32 = add <4 x i64> %wide.load22, %20                   
  %38 = add <4 x i64> %wide.load76, %26                   ⟪╋⟫  %33 = add <4 x i64> %wide.load23, %21                   
  %39 = add <4 x i64> %wide.load77, %27                   ⟪╋⟫  %34 = add <4 x i64> %wide.load24, %22                   
  %40 = add <4 x i64> %wide.load78, %28                   ⟪╋⟫  %35 = add <4 x i64> %wide.load25, %23                   
  %41 = getelementptr inbounds i64, i64* %arrayptr2331, i…⟪╋⟫  %36 = getelementptr inbounds i64, i64* %arrayptr510, i6…
  %42 = bitcast i64* %41 to <4 x i64>*                    ⟪╋⟫  %37 = bitcast i64* %36 to <4 x i64>*                    
  store <4 x i64> %37, <4 x i64>* %42, align 8            ⟪╋⟫  store <4 x i64> %32, <4 x i64>* %37, align 8            
  %43 = getelementptr inbounds i64, i64* %41, i64 4       ⟪╋⟫  %38 = getelementptr inbounds i64, i64* %36, i64 4       
  %44 = bitcast i64* %43 to <4 x i64>*                    ⟪╋⟫  %39 = bitcast i64* %38 to <4 x i64>*                    
  store <4 x i64> %38, <4 x i64>* %44, align 8            ⟪╋⟫  store <4 x i64> %33, <4 x i64>* %39, align 8            
  %45 = getelementptr inbounds i64, i64* %41, i64 8       ⟪╋⟫  %40 = getelementptr inbounds i64, i64* %36, i64 8       
  %46 = bitcast i64* %45 to <4 x i64>*                    ⟪╋⟫  %41 = bitcast i64* %40 to <4 x i64>*                    
  store <4 x i64> %39, <4 x i64>* %46, align 8            ⟪╋⟫  store <4 x i64> %34, <4 x i64>* %41, align 8            
  %47 = getelementptr inbounds i64, i64* %41, i64 12      ⟪╋⟫  %42 = getelementptr inbounds i64, i64* %36, i64 12      
  %48 = bitcast i64* %47 to <4 x i64>*                    ⟪╋⟫  %43 = bitcast i64* %42 to <4 x i64>*                    
  store <4 x i64> %40, <4 x i64>* %48, align 8            ⟪╋⟫  store <4 x i64> %35, <4 x i64>* %43, align 8            
  %index.next = or i64 %index, 16                          ┃   %index.next = or i64 %index, 16                         
  %49 = getelementptr inbounds i64, i64* %arrayptr29, i64…⟪╋⟫  %44 = getelementptr inbounds i64, i64* %arrayptr8, i64 …
  %50 = bitcast i64* %49 to <4 x i64>*                    ⟪╋⟫  %45 = bitcast i64* %44 to <4 x i64>*                    
  %wide.load.1 = load <4 x i64>, <4 x i64>* %50, align 8  ⟪╋⟫  %wide.load.1 = load <4 x i64>, <4 x i64>* %45, align 8  
  %51 = getelementptr inbounds i64, i64* %49, i64 4       ⟪╋⟫  %46 = getelementptr inbounds i64, i64* %44, i64 4       
  %52 = bitcast i64* %51 to <4 x i64>*                    ⟪╋⟫  %47 = bitcast i64* %46 to <4 x i64>*                    
  %wide.load66.1 = load <4 x i64>, <4 x i64>* %52, align …⟪╋⟫  %wide.load13.1 = load <4 x i64>, <4 x i64>* %47, align …
  %53 = getelementptr inbounds i64, i64* %49, i64 8       ⟪╋⟫  %48 = getelementptr inbounds i64, i64* %44, i64 8       
  %54 = bitcast i64* %53 to <4 x i64>*                    ⟪╋⟫  %49 = bitcast i64* %48 to <4 x i64>*                    
  %wide.load67.1 = load <4 x i64>, <4 x i64>* %54, align …⟪╋⟫  %wide.load14.1 = load <4 x i64>, <4 x i64>* %49, align …
  %55 = getelementptr inbounds i64, i64* %49, i64 12      ⟪╋⟫  %50 = getelementptr inbounds i64, i64* %44, i64 12      
  %56 = bitcast i64* %55 to <4 x i64>*                    ⟪╋⟫  %51 = bitcast i64* %50 to <4 x i64>*                    
  %wide.load68.1 = load <4 x i64>, <4 x i64>* %56, align …⟪╋⟫  %wide.load15.1 = load <4 x i64>, <4 x i64>* %51, align …
  %57 = mul <4 x i64> %wide.load.1, %broadcast.splat      ⟪╋⟫  %52 = mul <4 x i64> %wide.load.1, %broadcast.splat      
  %58 = mul <4 x i64> %wide.load66.1, %broadcast.splat    ⟪╋⟫  %53 = mul <4 x i64> %wide.load13.1, %broadcast.splat    
  %59 = mul <4 x i64> %wide.load67.1, %broadcast.splat    ⟪╋⟫  %54 = mul <4 x i64> %wide.load14.1, %broadcast.splat    
  %60 = mul <4 x i64> %wide.load68.1, %broadcast.splat    ⟪╋⟫  %55 = mul <4 x i64> %wide.load15.1, %broadcast.splat    
  %61 = getelementptr inbounds i64, i64* %arrayptr1430, i…⟪╋⟫  %56 = getelementptr inbounds i64, i64* %arrayptr29, i64…
  %62 = bitcast i64* %61 to <4 x i64>*                    ⟪╋⟫  %57 = bitcast i64* %56 to <4 x i64>*                    
  %wide.load75.1 = load <4 x i64>, <4 x i64>* %62, align …⟪╋⟫  %wide.load22.1 = load <4 x i64>, <4 x i64>* %57, align …
  %63 = getelementptr inbounds i64, i64* %61, i64 4       ⟪╋⟫  %58 = getelementptr inbounds i64, i64* %56, i64 4       
  %64 = bitcast i64* %63 to <4 x i64>*                    ⟪╋⟫  %59 = bitcast i64* %58 to <4 x i64>*                    
  %wide.load76.1 = load <4 x i64>, <4 x i64>* %64, align …⟪╋⟫  %wide.load23.1 = load <4 x i64>, <4 x i64>* %59, align …
  %65 = getelementptr inbounds i64, i64* %61, i64 8       ⟪╋⟫  %60 = getelementptr inbounds i64, i64* %56, i64 8       
  %66 = bitcast i64* %65 to <4 x i64>*                    ⟪╋⟫  %61 = bitcast i64* %60 to <4 x i64>*                    
  %wide.load77.1 = load <4 x i64>, <4 x i64>* %66, align …⟪╋⟫  %wide.load24.1 = load <4 x i64>, <4 x i64>* %61, align …
  %67 = getelementptr inbounds i64, i64* %61, i64 12      ⟪╋⟫  %62 = getelementptr inbounds i64, i64* %56, i64 12      
  %68 = bitcast i64* %67 to <4 x i64>*                    ⟪╋⟫  %63 = bitcast i64* %62 to <4 x i64>*                    
  %wide.load78.1 = load <4 x i64>, <4 x i64>* %68, align …⟪╋⟫  %wide.load25.1 = load <4 x i64>, <4 x i64>* %63, align …
  %69 = add <4 x i64> %wide.load75.1, %57                 ⟪╋⟫  %64 = add <4 x i64> %wide.load22.1, %52                 
  %70 = add <4 x i64> %wide.load76.1, %58                 ⟪╋⟫  %65 = add <4 x i64> %wide.load23.1, %53                 
  %71 = add <4 x i64> %wide.load77.1, %59                 ⟪╋⟫  %66 = add <4 x i64> %wide.load24.1, %54                 
  %72 = add <4 x i64> %wide.load78.1, %60                 ⟪╋⟫  %67 = add <4 x i64> %wide.load25.1, %55                 
  %73 = getelementptr inbounds i64, i64* %arrayptr2331, i…⟪╋⟫  %68 = getelementptr inbounds i64, i64* %arrayptr510, i6…
  %74 = bitcast i64* %73 to <4 x i64>*                    ⟪╋⟫  %69 = bitcast i64* %68 to <4 x i64>*                    
  store <4 x i64> %69, <4 x i64>* %74, align 8            ⟪╋⟫  store <4 x i64> %64, <4 x i64>* %69, align 8            
  %75 = getelementptr inbounds i64, i64* %73, i64 4       ⟪╋⟫  %70 = getelementptr inbounds i64, i64* %68, i64 4       
  %76 = bitcast i64* %75 to <4 x i64>*                    ⟪╋⟫  %71 = bitcast i64* %70 to <4 x i64>*                    
  store <4 x i64> %70, <4 x i64>* %76, align 8            ⟪╋⟫  store <4 x i64> %65, <4 x i64>* %71, align 8            
  %77 = getelementptr inbounds i64, i64* %73, i64 8       ⟪╋⟫  %72 = getelementptr inbounds i64, i64* %68, i64 8       
  %78 = bitcast i64* %77 to <4 x i64>*                    ⟪╋⟫  %73 = bitcast i64* %72 to <4 x i64>*                    
  store <4 x i64> %71, <4 x i64>* %78, align 8            ⟪╋⟫  store <4 x i64> %66, <4 x i64>* %73, align 8            
  %79 = getelementptr inbounds i64, i64* %73, i64 12      ⟪╋⟫  %74 = getelementptr inbounds i64, i64* %68, i64 12      
  %80 = bitcast i64* %79 to <4 x i64>*                    ⟪╋⟫  %75 = bitcast i64* %74 to <4 x i64>*                    
  store <4 x i64> %72, <4 x i64>* %80, align 8            ⟪╋⟫  store <4 x i64> %67, <4 x i64>* %75, align 8            
  %index.next.1 = add nuw i64 %index, 32                   ┃   %index.next.1 = add nuw i64 %index, 32                  
  %niter.next.1 = add i64 %niter, 2                        ┃   %niter.next.1 = add i64 %niter, 2                       
  %niter.ncmp.1 = icmp eq i64 %niter.next.1, %unroll_iter  ┃   %niter.ncmp.1 = icmp eq i64 %niter.next.1, %unroll_iter 
  br i1 %niter.ncmp.1, label %middle.block.unr-lcssa, lab… ┃   br i1 %niter.ncmp.1, label %middle.block.unr-lcssa, lab…
                                                           ┃                                                           
middle.block.unr-lcssa:                           ; preds… ┃ middle.block.unr-lcssa:                           ; preds…
  %index.unr = phi i64 [ 0, %vector.ph ], [ %index.next.1… ┃   %index.unr = phi i64 [ 0, %vector.ph ], [ %index.next.1…
  %lcmp.mod.not = icmp eq i64 %xtraiter, 0                 ┃   %lcmp.mod.not = icmp eq i64 %xtraiter, 0                
  br i1 %lcmp.mod.not, label %middle.block, label %vector… ┃   br i1 %lcmp.mod.not, label %middle.block, label %vector…
                                                           ┃                                                           
vector.body.epil.preheader:                       ; preds… ┃ vector.body.epil.preheader:                       ; preds…
  %81 = getelementptr inbounds i64, i64* %arrayptr29, i64…⟪╋⟫  %76 = getelementptr inbounds i64, i64* %arrayptr8, i64 …
  %82 = bitcast i64* %81 to <4 x i64>*                    ⟪╋⟫  %77 = bitcast i64* %76 to <4 x i64>*                    
  %wide.load.epil = load <4 x i64>, <4 x i64>* %82, align…⟪╋⟫  %wide.load.epil = load <4 x i64>, <4 x i64>* %77, align…
  %83 = getelementptr inbounds i64, i64* %81, i64 4       ⟪╋⟫  %78 = getelementptr inbounds i64, i64* %76, i64 4       
  %84 = bitcast i64* %83 to <4 x i64>*                    ⟪╋⟫  %79 = bitcast i64* %78 to <4 x i64>*                    
  %wide.load66.epil = load <4 x i64>, <4 x i64>* %84, ali…⟪╋⟫  %wide.load13.epil = load <4 x i64>, <4 x i64>* %79, ali…
  %85 = getelementptr inbounds i64, i64* %81, i64 8       ⟪╋⟫  %80 = getelementptr inbounds i64, i64* %76, i64 8       
  %86 = bitcast i64* %85 to <4 x i64>*                    ⟪╋⟫  %81 = bitcast i64* %80 to <4 x i64>*                    
  %wide.load67.epil = load <4 x i64>, <4 x i64>* %86, ali…⟪╋⟫  %wide.load14.epil = load <4 x i64>, <4 x i64>* %81, ali…
  %87 = getelementptr inbounds i64, i64* %81, i64 12      ⟪╋⟫  %82 = getelementptr inbounds i64, i64* %76, i64 12      
  %88 = bitcast i64* %87 to <4 x i64>*                    ⟪╋⟫  %83 = bitcast i64* %82 to <4 x i64>*                    
  %wide.load68.epil = load <4 x i64>, <4 x i64>* %88, ali…⟪╋⟫  %wide.load15.epil = load <4 x i64>, <4 x i64>* %83, ali…
  %89 = mul <4 x i64> %wide.load.epil, %broadcast.splat   ⟪╋⟫  %84 = mul <4 x i64> %wide.load.epil, %broadcast.splat   
  %90 = mul <4 x i64> %wide.load66.epil, %broadcast.splat ⟪╋⟫  %85 = mul <4 x i64> %wide.load13.epil, %broadcast.splat 
  %91 = mul <4 x i64> %wide.load67.epil, %broadcast.splat ⟪╋⟫  %86 = mul <4 x i64> %wide.load14.epil, %broadcast.splat 
  %92 = mul <4 x i64> %wide.load68.epil, %broadcast.splat ⟪╋⟫  %87 = mul <4 x i64> %wide.load15.epil, %broadcast.splat 
  %93 = getelementptr inbounds i64, i64* %arrayptr1430, i…⟪╋⟫  %88 = getelementptr inbounds i64, i64* %arrayptr29, i64…
  %94 = bitcast i64* %93 to <4 x i64>*                    ⟪╋⟫  %89 = bitcast i64* %88 to <4 x i64>*                    
  %wide.load75.epil = load <4 x i64>, <4 x i64>* %94, ali…⟪╋⟫  %wide.load22.epil = load <4 x i64>, <4 x i64>* %89, ali…
  %95 = getelementptr inbounds i64, i64* %93, i64 4       ⟪╋⟫  %90 = getelementptr inbounds i64, i64* %88, i64 4       
  %96 = bitcast i64* %95 to <4 x i64>*                    ⟪╋⟫  %91 = bitcast i64* %90 to <4 x i64>*                    
  %wide.load76.epil = load <4 x i64>, <4 x i64>* %96, ali…⟪╋⟫  %wide.load23.epil = load <4 x i64>, <4 x i64>* %91, ali…
  %97 = getelementptr inbounds i64, i64* %93, i64 8       ⟪╋⟫  %92 = getelementptr inbounds i64, i64* %88, i64 8       
  %98 = bitcast i64* %97 to <4 x i64>*                    ⟪╋⟫  %93 = bitcast i64* %92 to <4 x i64>*                    
  %wide.load77.epil = load <4 x i64>, <4 x i64>* %98, ali…⟪╋⟫  %wide.load24.epil = load <4 x i64>, <4 x i64>* %93, ali…
  %99 = getelementptr inbounds i64, i64* %93, i64 12      ⟪╋⟫  %94 = getelementptr inbounds i64, i64* %88, i64 12      
  %100 = bitcast i64* %99 to <4 x i64>*                   ⟪╋⟫  %95 = bitcast i64* %94 to <4 x i64>*                    
  %wide.load78.epil = load <4 x i64>, <4 x i64>* %100, al…⟪╋⟫  %wide.load25.epil = load <4 x i64>, <4 x i64>* %95, ali…
  %101 = add <4 x i64> %wide.load75.epil, %89             ⟪╋⟫  %96 = add <4 x i64> %wide.load22.epil, %84              
  %102 = add <4 x i64> %wide.load76.epil, %90             ⟪╋⟫  %97 = add <4 x i64> %wide.load23.epil, %85              
  %103 = add <4 x i64> %wide.load77.epil, %91             ⟪╋⟫  %98 = add <4 x i64> %wide.load24.epil, %86              
  %104 = add <4 x i64> %wide.load78.epil, %92             ⟪╋⟫  %99 = add <4 x i64> %wide.load25.epil, %87              
  %105 = getelementptr inbounds i64, i64* %arrayptr2331, …⟪╋⟫  %100 = getelementptr inbounds i64, i64* %arrayptr510, i…
  %106 = bitcast i64* %105 to <4 x i64>*                  ⟪╋⟫  %101 = bitcast i64* %100 to <4 x i64>*                  
  store <4 x i64> %101, <4 x i64>* %106, align 8          ⟪╋⟫  store <4 x i64> %96, <4 x i64>* %101, align 8           
  %107 = getelementptr inbounds i64, i64* %105, i64 4     ⟪╋⟫  %102 = getelementptr inbounds i64, i64* %100, i64 4     
  %108 = bitcast i64* %107 to <4 x i64>*                  ⟪╋⟫  %103 = bitcast i64* %102 to <4 x i64>*                  
  store <4 x i64> %102, <4 x i64>* %108, align 8          ⟪╋⟫  store <4 x i64> %97, <4 x i64>* %103, align 8           
  %109 = getelementptr inbounds i64, i64* %105, i64 8     ⟪╋⟫  %104 = getelementptr inbounds i64, i64* %100, i64 8     
  %110 = bitcast i64* %109 to <4 x i64>*                  ⟪╋⟫  %105 = bitcast i64* %104 to <4 x i64>*                  
  store <4 x i64> %103, <4 x i64>* %110, align 8          ⟪╋⟫  store <4 x i64> %98, <4 x i64>* %105, align 8           
  %111 = getelementptr inbounds i64, i64* %105, i64 12    ⟪╋⟫  %106 = getelementptr inbounds i64, i64* %100, i64 12    
  %112 = bitcast i64* %111 to <4 x i64>*                  ⟪╋⟫  %107 = bitcast i64* %106 to <4 x i64>*                  
  store <4 x i64> %104, <4 x i64>* %112, align 8          ⟪╋⟫  store <4 x i64> %99, <4 x i64>* %107, align 8           
  br label %middle.block                                   ┃   br label %middle.block                                  
                                                           ┃                                                           
middle.block:                                     ; preds… ┃ middle.block:                                     ; preds…
  %cmp.n = icmp eq i64 %exit.mainloop.at, %n.vec          ⟪╋⟫  %cmp.n = icmp eq i64 %arraylen, %n.vec                  
  br i1 %cmp.n, label %main.exit.selector, label %scalar.…⟪┫                                                           
                                                          ⟪┫                                                           
scalar.ph:                                        ; preds…⟪┫                                                           
  %bc.resume.val = phi i64 [ %ind.end, %middle.block ], […⟪┫                                                           
  br label %idxend21                                      ⟪┫                                                           
                                                          ⟪┫                                                           
L31:                                              ; preds…⟪┫                                                           
  ret void                                                ⟪┫                                                           
                                                          ⟪┫                                                           
oob:                                              ; preds…⟪┫                                                           
  %errorbox = alloca i64, align 8                         ⟪┫                                                           
  store i64 %value_phi3.postloop, i64* %errorbox, align 8 ⟪┫                                                           
  call void @ijl_bounds_error_ints({}* %2, i64* nonnull %…⟪┫                                                           
  unreachable                                             ⟪┫                                                           
                                                          ⟪┫                                                           
oob10:                                            ; preds…⟪┫                                                           
  %errorbox11 = alloca i64, align 8                       ⟪┫                                                           
  store i64 %value_phi3.postloop, i64* %errorbox11, align…⟪┫                                                           
  call void @ijl_bounds_error_ints({}* %3, i64* nonnull %…⟪┫                                                           
  unreachable                                             ⟪┫                                                           
                                                          ⟪┫                                                           
oob19:                                            ; preds…⟪┫                                                           
  %errorbox20 = alloca i64, align 8                       ⟪┫                                                           
  store i64 %value_phi3.postloop, i64* %errorbox20, align…⟪┫                                                           
  call void @ijl_bounds_error_ints({}* %0, i64* nonnull %…⟪┫                                                           
  unreachable                                             ⟪┫                                                           
                                                          ⟪┫                                                           
idxend21:                                         ; preds…⟪┫                                                           
  %value_phi3 = phi i64 [ %119, %idxend21 ], [ %bc.resume…⟪┫                                                           
  %113 = add nsw i64 %value_phi3, -1                      ⟪┫                                                           
  %114 = getelementptr inbounds i64, i64* %arrayptr29, i6…⟪┫                                                           
  %arrayref = load i64, i64* %114, align 8                ⟪┫                                                           
  %115 = mul i64 %arrayref, %1                            ⟪┫                                                           
  %116 = getelementptr inbounds i64, i64* %arrayptr1430, …⟪┫                                                           
  %arrayref15 = load i64, i64* %116, align 8              ⟪┫                                                           
  %117 = add i64 %arrayref15, %115                        ⟪┫                                                           
  %118 = getelementptr inbounds i64, i64* %arrayptr2331, …⟪┫                                                           
  store i64 %117, i64* %118, align 8                      ⟪┫                                                           
  %119 = add nuw nsw i64 %value_phi3, 1                   ⟪┫                                                           
  %.not51 = icmp ult i64 %value_phi3, %exit.mainloop.at   ⟪┫                                                           
  br i1 %.not51, label %idxend21, label %main.exit.select…⟪┫                                                           
                                                          ⟪┫                                                           
main.exit.selector:                               ; preds…⟪┫                                                           
  %value_phi3.lcssa = phi i64 [ %exit.mainloop.at, %middl…⟪┫                                                           
  %.lcssa = phi i64 [ %ind.end, %middle.block ], [ %119, …⟪┫                                                           
  %120 = icmp ult i64 %value_phi3.lcssa, %arraylen        ⟪┫                                                           
  br i1 %120, label %main.pseudo.exit, label %L31         ⟪┫                                                           
                                                          ⟪┫                                                           
main.pseudo.exit:                                 ; preds…⟪┫                                                           
  %value_phi3.copy = phi i64 [ 1, %L13.preheader ], [ %.l…⟪┫                                                           
  br label %L13.postloop                                  ⟪┫                                                           
                                                          ⟪┫                                                           
L13.postloop:                                     ; preds…⟪┫                                                           
  %value_phi3.postloop = phi i64 [ %127, %idxend21.postlo…⟪┫                                                           
  %121 = add i64 %value_phi3.postloop, -1                 ⟪┫                                                           
  %inbounds.postloop = icmp ult i64 %121, %arraylen6      ⟪┫                                                           
  br i1 %inbounds.postloop, label %idxend.postloop, label…⟪┫                                                           
                                                           ┣⟫  br i1 %cmp.n, label %L32, label %scalar.ph              
                                                           ┃                                                           
idxend.postloop:                                  ; preds…⟪┫                                                           
  %inbounds9.postloop = icmp ult i64 %121, %arraylen8     ⟪┫                                                           
  br i1 %inbounds9.postloop, label %idxend12.postloop, la…⟪┫                                                           
                                                           ┣⟫scalar.ph:                                        ; preds…
                                                           ┣⟫  %bc.resume.val = phi i64 [ %n.vec, %middle.block ], [ 0…
                                                           ┣⟫  br label %L12                                           
                                                           ┃                                                           
idxend12.postloop:                                ; preds…⟪┫                                                           
  %inbounds18.postloop = icmp ult i64 %121, %arraylen     ⟪┫                                                           
  br i1 %inbounds18.postloop, label %idxend21.postloop, l…⟪┫                                                           
                                                           ┣⟫L12:                                              ; preds…
                                                           ┣⟫  %value_phi12 = phi i64 [ %bc.resume.val, %scalar.ph ], …
                                                           ┣⟫  %108 = getelementptr inbounds i64, i64* %arrayptr8, i64…
                                                           ┣⟫  %arrayref = load i64, i64* %108, align 8                
                                                           ┣⟫  %109 = mul i64 %arrayref, %1                            
                                                           ┣⟫  %110 = getelementptr inbounds i64, i64* %arrayptr29, i6…
                                                           ┣⟫  %arrayref3 = load i64, i64* %110, align 8               
                                                           ┣⟫  %111 = add i64 %arrayref3, %109                         
                                                           ┣⟫  %112 = getelementptr inbounds i64, i64* %arrayptr510, i…
                                                           ┣⟫  store i64 %111, i64* %112, align 8                      
                                                           ┣⟫  %113 = add nuw nsw i64 %value_phi12, 1                  
                                                           ┣⟫  %exitcond.not = icmp eq i64 %113, %arraylen             
                                                           ┣⟫  br i1 %exitcond.not, label %L32, label %L12             
                                                           ┃                                                           
idxend21.postloop:                                ; preds…⟪┫                                                           
  %122 = getelementptr inbounds i64, i64* %arrayptr29, i6…⟪┫                                                           
  %arrayref.postloop = load i64, i64* %122, align 8       ⟪┫                                                           
  %123 = mul i64 %arrayref.postloop, %1                   ⟪┫                                                           
  %124 = getelementptr inbounds i64, i64* %arrayptr1430, …⟪┫                                                           
  %arrayref15.postloop = load i64, i64* %124, align 8     ⟪┫                                                           
  %125 = add i64 %arrayref15.postloop, %123               ⟪┫                                                           
  %126 = getelementptr inbounds i64, i64* %arrayptr2331, …⟪┫                                                           
  store i64 %125, i64* %126, align 8                      ⟪┫                                                           
  %.not.not32.postloop = icmp eq i64 %value_phi3.postloop…⟪┫                                                           
  %127 = add nuw nsw i64 %value_phi3.postloop, 1          ⟪┫                                                           
  br i1 %.not.not32.postloop, label %L31, label %L13.post…⟪┫                                                           
                                                           ┣⟫L32:                                              ; preds…
                                                           ┣⟫  ret void                                                
}                                                          ┃ }                                                         
                                                           ┃                                                           