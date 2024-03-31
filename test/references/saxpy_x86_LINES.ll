  1 ; Function Attrs: uwtable                              ┃ ; Function Attrs: uwtable                             1  
  2 define void @saxpy({}* noundef nonnull align 16 deref…⟪╋⟫define void @saxpy_simd({}* noundef nonnull align 16 …2  
  3 top:                                                   ┃ top:                                                  3  
  4   %4 = bitcast {}* %0 to { i8*, i64, i16, i16, i32 }*  ┃   %4 = bitcast {}* %0 to { i8*, i64, i16, i16, i32 }* 4  
  5   %arraylen_ptr = getelementptr inbounds { i8*, i64, … ┃   %arraylen_ptr = getelementptr inbounds { i8*, i64, …5  
  6   %arraylen = load i64, i64* %arraylen_ptr, align 8    ┃   %arraylen = load i64, i64* %arraylen_ptr, align 8   6  
  7   %.not.not = icmp eq i64 %arraylen, 0                ⟪╋⟫  %.not = icmp eq i64 %arraylen, 0                    7  
  8   br i1 %.not.not, label %L31, label %L13.preheader   ⟪╋⟫  br i1 %.not, label %L32, label %L12.lr.ph           8  
  9                                                       ⟪┫                                                       
 10 L13.preheader:                                    ; p…⟪┫                                                       
 11   %5 = bitcast {}* %2 to { i8*, i64, i16, i16, i32 }* ⟪┫                                                       
 12   %arraylen_ptr5 = getelementptr inbounds { i8*, i64,…⟪┫                                                       
 13   %arraylen6 = load i64, i64* %arraylen_ptr5, align 8 ⟪┫                                                       
 14   %6 = bitcast {}* %3 to { i8*, i64, i16, i16, i32 }* ⟪┫                                                       
 15   %arraylen_ptr7 = getelementptr inbounds { i8*, i64,…⟪┫                                                       
 16   %arraylen8 = load i64, i64* %arraylen_ptr7, align 8 ⟪┫                                                       
 17   %7 = bitcast {}* %2 to i64**                        ⟪┫                                                       
 18   %arrayptr29 = load i64*, i64** %7, align 8          ⟪┫                                                       
 19   %8 = bitcast {}* %3 to i64**                        ⟪┫                                                       
 20   %arrayptr1430 = load i64*, i64** %8, align 8        ⟪┫                                                       
 21   %9 = bitcast {}* %0 to i64**                        ⟪┫                                                       
 22   %arrayptr2331 = load i64*, i64** %9, align 8        ⟪┫                                                       
 23   %umin = call i64 @llvm.umin.i64(i64 %arraylen6, i64…⟪┫                                                       
 24   %smin = call i64 @llvm.smin.i64(i64 %arraylen8, i64…⟪┫                                                       
 25   %10 = sub i64 %arraylen8, %smin                     ⟪┫                                                       
 26   %smax = call i64 @llvm.smax.i64(i64 %smin, i64 -1)  ⟪┫                                                       
 27   %11 = add nsw i64 %smax, 1                          ⟪┫                                                       
 28   %12 = mul nuw nsw i64 %10, %11                      ⟪┫                                                       
 29   %umin36 = call i64 @llvm.umin.i64(i64 %umin, i64 %1…⟪┫                                                       
 30   %exit.mainloop.at = call i64 @llvm.umin.i64(i64 %um…⟪┫                                                       
 31   %.not = icmp eq i64 %exit.mainloop.at, 0            ⟪┫                                                       
 32   br i1 %.not, label %main.pseudo.exit, label %idxend…⟪┫                                                       
 33                                                       ⟪┫                                                       
 34 idxend21.preheader:                               ; p…⟪┫                                                       
 35   %min.iters.check = icmp ult i64 %exit.mainloop.at, …⟪┫                                                       
 36   br i1 %min.iters.check, label %scalar.ph, label %ve…⟪┫                                                       
 37                                                        ┃                                                       9  
 38 vector.memcheck:                                  ; p…⟪┫                                                       
 39   %scevgep = getelementptr i64, i64* %arrayptr2331, i…⟪┫                                                       
 40   %scevgep58 = getelementptr i64, i64* %arrayptr29, i…⟪┫                                                       
 41   %scevgep61 = getelementptr i64, i64* %arrayptr1430,…⟪┫                                                       
 42   %bound0 = icmp ult i64* %arrayptr2331, %scevgep58   ⟪┫                                                       
 43   %bound1 = icmp ult i64* %arrayptr29, %scevgep       ⟪┫                                                       
 44   %found.conflict = and i1 %bound0, %bound1           ⟪┫                                                       
 45   %bound063 = icmp ult i64* %arrayptr2331, %scevgep61 ⟪┫                                                       
 46   %bound164 = icmp ult i64* %arrayptr1430, %scevgep   ⟪┫                                                       
 47   %found.conflict65 = and i1 %bound063, %bound164     ⟪┫                                                       
 48   %conflict.rdx = or i1 %found.conflict, %found.confl…⟪┫                                                       
 49   br i1 %conflict.rdx, label %scalar.ph, label %vecto…⟪╋⟫  br i1 %min.iters.check, label %scalar.ph, label %ve…10 
                                                           ┣⟫L12.lr.ph:                                        ; p…11 
                                                           ┣⟫  %5 = bitcast {}* %2 to i64**                        12 
                                                           ┣⟫  %arrayptr8 = load i64*, i64** %5, align 8           13 
                                                           ┣⟫  %6 = bitcast {}* %3 to i64**                        14 
                                                           ┣⟫  %arrayptr29 = load i64*, i64** %6, align 8          15 
                                                           ┣⟫  %7 = bitcast {}* %0 to i64**                        16 
                                                           ┣⟫  %arrayptr510 = load i64*, i64** %7, align 8         17 
                                                           ┣⟫  %min.iters.check = icmp ult i64 %arraylen, 16       18 
 50                                                        ┃                                                       19 
 51 vector.ph:                                        ; p…⟪╋⟫vector.ph:                                        ; p…20 
 52   %n.vec = and i64 %exit.mainloop.at, 922337203685477…⟪╋⟫  %n.vec = and i64 %arraylen, 9223372036854775792     21 
 53   %ind.end = or i64 %n.vec, 1                         ⟪┫                                                       
 54   %broadcast.splatinsert = insertelement <4 x i64> po… ┃   %broadcast.splatinsert = insertelement <4 x i64> po…22 
 55   %broadcast.splat = shufflevector <4 x i64> %broadca… ┃   %broadcast.splat = shufflevector <4 x i64> %broadca…23 
 56   %13 = add nsw i64 %n.vec, -16                       ⟪╋⟫  %8 = add nsw i64 %n.vec, -16                        24 
 57   %14 = lshr exact i64 %13, 4                         ⟪╋⟫  %9 = lshr exact i64 %8, 4                           25 
 58   %15 = add nuw nsw i64 %14, 1                        ⟪╋⟫  %10 = add nuw nsw i64 %9, 1                         26 
 59   %xtraiter = and i64 %15, 1                          ⟪╋⟫  %xtraiter = and i64 %10, 1                          27 
 60   %16 = icmp eq i64 %13, 0                            ⟪╋⟫  %11 = icmp eq i64 %8, 0                             28 
 61   br i1 %16, label %middle.block.unr-lcssa, label %ve…⟪╋⟫  br i1 %11, label %middle.block.unr-lcssa, label %ve…29 
 62                                                        ┃                                                       30 
 63 vector.ph.new:                                    ; p… ┃ vector.ph.new:                                    ; p…31 
 64   %unroll_iter = and i64 %15, 2305843009213693950     ⟪╋⟫  %unroll_iter = and i64 %10, 2305843009213693950     32 
 65   br label %vector.body                                ┃   br label %vector.body                               33 
 66                                                        ┃                                                       34 
 67 vector.body:                                      ; p… ┃ vector.body:                                      ; p…35 
 68   %index = phi i64 [ 0, %vector.ph.new ], [ %index.ne… ┃   %index = phi i64 [ 0, %vector.ph.new ], [ %index.ne…36 
 69   %niter = phi i64 [ 0, %vector.ph.new ], [ %niter.ne… ┃   %niter = phi i64 [ 0, %vector.ph.new ], [ %niter.ne…37 
 70   %17 = getelementptr inbounds i64, i64* %arrayptr29,…⟪╋⟫  %12 = getelementptr inbounds i64, i64* %arrayptr8, …38 
 71   %18 = bitcast i64* %17 to <4 x i64>*                ⟪╋⟫  %13 = bitcast i64* %12 to <4 x i64>*                39 
 72   %wide.load = load <4 x i64>, <4 x i64>* %18, align …⟪╋⟫  %wide.load = load <4 x i64>, <4 x i64>* %13, align …40 
 73   %19 = getelementptr inbounds i64, i64* %17, i64 4   ⟪╋⟫  %14 = getelementptr inbounds i64, i64* %12, i64 4   41 
 74   %20 = bitcast i64* %19 to <4 x i64>*                ⟪╋⟫  %15 = bitcast i64* %14 to <4 x i64>*                42 
 75   %wide.load66 = load <4 x i64>, <4 x i64>* %20, alig…⟪╋⟫  %wide.load13 = load <4 x i64>, <4 x i64>* %15, alig…43 
 76   %21 = getelementptr inbounds i64, i64* %17, i64 8   ⟪╋⟫  %16 = getelementptr inbounds i64, i64* %12, i64 8   44 
 77   %22 = bitcast i64* %21 to <4 x i64>*                ⟪╋⟫  %17 = bitcast i64* %16 to <4 x i64>*                45 
 78   %wide.load67 = load <4 x i64>, <4 x i64>* %22, alig…⟪╋⟫  %wide.load14 = load <4 x i64>, <4 x i64>* %17, alig…46 
 79   %23 = getelementptr inbounds i64, i64* %17, i64 12  ⟪╋⟫  %18 = getelementptr inbounds i64, i64* %12, i64 12  47 
 80   %24 = bitcast i64* %23 to <4 x i64>*                ⟪╋⟫  %19 = bitcast i64* %18 to <4 x i64>*                48 
 81   %wide.load68 = load <4 x i64>, <4 x i64>* %24, alig…⟪╋⟫  %wide.load15 = load <4 x i64>, <4 x i64>* %19, alig…49 
 82   %25 = mul <4 x i64> %wide.load, %broadcast.splat    ⟪╋⟫  %20 = mul <4 x i64> %wide.load, %broadcast.splat    50 
 83   %26 = mul <4 x i64> %wide.load66, %broadcast.splat  ⟪╋⟫  %21 = mul <4 x i64> %wide.load13, %broadcast.splat  51 
 84   %27 = mul <4 x i64> %wide.load67, %broadcast.splat  ⟪╋⟫  %22 = mul <4 x i64> %wide.load14, %broadcast.splat  52 
 85   %28 = mul <4 x i64> %wide.load68, %broadcast.splat  ⟪╋⟫  %23 = mul <4 x i64> %wide.load15, %broadcast.splat  53 
 86   %29 = getelementptr inbounds i64, i64* %arrayptr143…⟪╋⟫  %24 = getelementptr inbounds i64, i64* %arrayptr29,…54 
 87   %30 = bitcast i64* %29 to <4 x i64>*                ⟪╋⟫  %25 = bitcast i64* %24 to <4 x i64>*                55 
 88   %wide.load75 = load <4 x i64>, <4 x i64>* %30, alig…⟪╋⟫  %wide.load22 = load <4 x i64>, <4 x i64>* %25, alig…56 
 89   %31 = getelementptr inbounds i64, i64* %29, i64 4   ⟪╋⟫  %26 = getelementptr inbounds i64, i64* %24, i64 4   57 
 90   %32 = bitcast i64* %31 to <4 x i64>*                ⟪╋⟫  %27 = bitcast i64* %26 to <4 x i64>*                58 
 91   %wide.load76 = load <4 x i64>, <4 x i64>* %32, alig…⟪╋⟫  %wide.load23 = load <4 x i64>, <4 x i64>* %27, alig…59 
 92   %33 = getelementptr inbounds i64, i64* %29, i64 8   ⟪╋⟫  %28 = getelementptr inbounds i64, i64* %24, i64 8   60 
 93   %34 = bitcast i64* %33 to <4 x i64>*                ⟪╋⟫  %29 = bitcast i64* %28 to <4 x i64>*                61 
 94   %wide.load77 = load <4 x i64>, <4 x i64>* %34, alig…⟪╋⟫  %wide.load24 = load <4 x i64>, <4 x i64>* %29, alig…62 
 95   %35 = getelementptr inbounds i64, i64* %29, i64 12  ⟪╋⟫  %30 = getelementptr inbounds i64, i64* %24, i64 12  63 
 96   %36 = bitcast i64* %35 to <4 x i64>*                ⟪╋⟫  %31 = bitcast i64* %30 to <4 x i64>*                64 
 97   %wide.load78 = load <4 x i64>, <4 x i64>* %36, alig…⟪╋⟫  %wide.load25 = load <4 x i64>, <4 x i64>* %31, alig…65 
 98   %37 = add <4 x i64> %wide.load75, %25               ⟪╋⟫  %32 = add <4 x i64> %wide.load22, %20               66 
 99   %38 = add <4 x i64> %wide.load76, %26               ⟪╋⟫  %33 = add <4 x i64> %wide.load23, %21               67 
100   %39 = add <4 x i64> %wide.load77, %27               ⟪╋⟫  %34 = add <4 x i64> %wide.load24, %22               68 
101   %40 = add <4 x i64> %wide.load78, %28               ⟪╋⟫  %35 = add <4 x i64> %wide.load25, %23               69 
102   %41 = getelementptr inbounds i64, i64* %arrayptr233…⟪╋⟫  %36 = getelementptr inbounds i64, i64* %arrayptr510…70 
103   %42 = bitcast i64* %41 to <4 x i64>*                ⟪╋⟫  %37 = bitcast i64* %36 to <4 x i64>*                71 
104   store <4 x i64> %37, <4 x i64>* %42, align 8        ⟪╋⟫  store <4 x i64> %32, <4 x i64>* %37, align 8        72 
105   %43 = getelementptr inbounds i64, i64* %41, i64 4   ⟪╋⟫  %38 = getelementptr inbounds i64, i64* %36, i64 4   73 
106   %44 = bitcast i64* %43 to <4 x i64>*                ⟪╋⟫  %39 = bitcast i64* %38 to <4 x i64>*                74 
107   store <4 x i64> %38, <4 x i64>* %44, align 8        ⟪╋⟫  store <4 x i64> %33, <4 x i64>* %39, align 8        75 
108   %45 = getelementptr inbounds i64, i64* %41, i64 8   ⟪╋⟫  %40 = getelementptr inbounds i64, i64* %36, i64 8   76 
109   %46 = bitcast i64* %45 to <4 x i64>*                ⟪╋⟫  %41 = bitcast i64* %40 to <4 x i64>*                77 
110   store <4 x i64> %39, <4 x i64>* %46, align 8        ⟪╋⟫  store <4 x i64> %34, <4 x i64>* %41, align 8        78 
111   %47 = getelementptr inbounds i64, i64* %41, i64 12  ⟪╋⟫  %42 = getelementptr inbounds i64, i64* %36, i64 12  79 
112   %48 = bitcast i64* %47 to <4 x i64>*                ⟪╋⟫  %43 = bitcast i64* %42 to <4 x i64>*                80 
113   store <4 x i64> %40, <4 x i64>* %48, align 8        ⟪╋⟫  store <4 x i64> %35, <4 x i64>* %43, align 8        81 
114   %index.next = or i64 %index, 16                      ┃   %index.next = or i64 %index, 16                     82 
115   %49 = getelementptr inbounds i64, i64* %arrayptr29,…⟪╋⟫  %44 = getelementptr inbounds i64, i64* %arrayptr8, …83 
116   %50 = bitcast i64* %49 to <4 x i64>*                ⟪╋⟫  %45 = bitcast i64* %44 to <4 x i64>*                84 
117   %wide.load.1 = load <4 x i64>, <4 x i64>* %50, alig…⟪╋⟫  %wide.load.1 = load <4 x i64>, <4 x i64>* %45, alig…85 
118   %51 = getelementptr inbounds i64, i64* %49, i64 4   ⟪╋⟫  %46 = getelementptr inbounds i64, i64* %44, i64 4   86 
119   %52 = bitcast i64* %51 to <4 x i64>*                ⟪╋⟫  %47 = bitcast i64* %46 to <4 x i64>*                87 
120   %wide.load66.1 = load <4 x i64>, <4 x i64>* %52, al…⟪╋⟫  %wide.load13.1 = load <4 x i64>, <4 x i64>* %47, al…88 
121   %53 = getelementptr inbounds i64, i64* %49, i64 8   ⟪╋⟫  %48 = getelementptr inbounds i64, i64* %44, i64 8   89 
122   %54 = bitcast i64* %53 to <4 x i64>*                ⟪╋⟫  %49 = bitcast i64* %48 to <4 x i64>*                90 
123   %wide.load67.1 = load <4 x i64>, <4 x i64>* %54, al…⟪╋⟫  %wide.load14.1 = load <4 x i64>, <4 x i64>* %49, al…91 
124   %55 = getelementptr inbounds i64, i64* %49, i64 12  ⟪╋⟫  %50 = getelementptr inbounds i64, i64* %44, i64 12  92 
125   %56 = bitcast i64* %55 to <4 x i64>*                ⟪╋⟫  %51 = bitcast i64* %50 to <4 x i64>*                93 
126   %wide.load68.1 = load <4 x i64>, <4 x i64>* %56, al…⟪╋⟫  %wide.load15.1 = load <4 x i64>, <4 x i64>* %51, al…94 
127   %57 = mul <4 x i64> %wide.load.1, %broadcast.splat  ⟪╋⟫  %52 = mul <4 x i64> %wide.load.1, %broadcast.splat  95 
128   %58 = mul <4 x i64> %wide.load66.1, %broadcast.spla…⟪╋⟫  %53 = mul <4 x i64> %wide.load13.1, %broadcast.spla…96 
129   %59 = mul <4 x i64> %wide.load67.1, %broadcast.spla…⟪╋⟫  %54 = mul <4 x i64> %wide.load14.1, %broadcast.spla…97 
130   %60 = mul <4 x i64> %wide.load68.1, %broadcast.spla…⟪╋⟫  %55 = mul <4 x i64> %wide.load15.1, %broadcast.spla…98 
131   %61 = getelementptr inbounds i64, i64* %arrayptr143…⟪╋⟫  %56 = getelementptr inbounds i64, i64* %arrayptr29,…99 
132   %62 = bitcast i64* %61 to <4 x i64>*                ⟪╋⟫  %57 = bitcast i64* %56 to <4 x i64>*                100
133   %wide.load75.1 = load <4 x i64>, <4 x i64>* %62, al…⟪╋⟫  %wide.load22.1 = load <4 x i64>, <4 x i64>* %57, al…101
134   %63 = getelementptr inbounds i64, i64* %61, i64 4   ⟪╋⟫  %58 = getelementptr inbounds i64, i64* %56, i64 4   102
135   %64 = bitcast i64* %63 to <4 x i64>*                ⟪╋⟫  %59 = bitcast i64* %58 to <4 x i64>*                103
136   %wide.load76.1 = load <4 x i64>, <4 x i64>* %64, al…⟪╋⟫  %wide.load23.1 = load <4 x i64>, <4 x i64>* %59, al…104
137   %65 = getelementptr inbounds i64, i64* %61, i64 8   ⟪╋⟫  %60 = getelementptr inbounds i64, i64* %56, i64 8   105
138   %66 = bitcast i64* %65 to <4 x i64>*                ⟪╋⟫  %61 = bitcast i64* %60 to <4 x i64>*                106
139   %wide.load77.1 = load <4 x i64>, <4 x i64>* %66, al…⟪╋⟫  %wide.load24.1 = load <4 x i64>, <4 x i64>* %61, al…107
140   %67 = getelementptr inbounds i64, i64* %61, i64 12  ⟪╋⟫  %62 = getelementptr inbounds i64, i64* %56, i64 12  108
141   %68 = bitcast i64* %67 to <4 x i64>*                ⟪╋⟫  %63 = bitcast i64* %62 to <4 x i64>*                109
142   %wide.load78.1 = load <4 x i64>, <4 x i64>* %68, al…⟪╋⟫  %wide.load25.1 = load <4 x i64>, <4 x i64>* %63, al…110
143   %69 = add <4 x i64> %wide.load75.1, %57             ⟪╋⟫  %64 = add <4 x i64> %wide.load22.1, %52             111
144   %70 = add <4 x i64> %wide.load76.1, %58             ⟪╋⟫  %65 = add <4 x i64> %wide.load23.1, %53             112
145   %71 = add <4 x i64> %wide.load77.1, %59             ⟪╋⟫  %66 = add <4 x i64> %wide.load24.1, %54             113
146   %72 = add <4 x i64> %wide.load78.1, %60             ⟪╋⟫  %67 = add <4 x i64> %wide.load25.1, %55             114
147   %73 = getelementptr inbounds i64, i64* %arrayptr233…⟪╋⟫  %68 = getelementptr inbounds i64, i64* %arrayptr510…115
148   %74 = bitcast i64* %73 to <4 x i64>*                ⟪╋⟫  %69 = bitcast i64* %68 to <4 x i64>*                116
149   store <4 x i64> %69, <4 x i64>* %74, align 8        ⟪╋⟫  store <4 x i64> %64, <4 x i64>* %69, align 8        117
150   %75 = getelementptr inbounds i64, i64* %73, i64 4   ⟪╋⟫  %70 = getelementptr inbounds i64, i64* %68, i64 4   118
151   %76 = bitcast i64* %75 to <4 x i64>*                ⟪╋⟫  %71 = bitcast i64* %70 to <4 x i64>*                119
152   store <4 x i64> %70, <4 x i64>* %76, align 8        ⟪╋⟫  store <4 x i64> %65, <4 x i64>* %71, align 8        120
153   %77 = getelementptr inbounds i64, i64* %73, i64 8   ⟪╋⟫  %72 = getelementptr inbounds i64, i64* %68, i64 8   121
154   %78 = bitcast i64* %77 to <4 x i64>*                ⟪╋⟫  %73 = bitcast i64* %72 to <4 x i64>*                122
155   store <4 x i64> %71, <4 x i64>* %78, align 8        ⟪╋⟫  store <4 x i64> %66, <4 x i64>* %73, align 8        123
156   %79 = getelementptr inbounds i64, i64* %73, i64 12  ⟪╋⟫  %74 = getelementptr inbounds i64, i64* %68, i64 12  124
157   %80 = bitcast i64* %79 to <4 x i64>*                ⟪╋⟫  %75 = bitcast i64* %74 to <4 x i64>*                125
158   store <4 x i64> %72, <4 x i64>* %80, align 8        ⟪╋⟫  store <4 x i64> %67, <4 x i64>* %75, align 8        126
159   %index.next.1 = add nuw i64 %index, 32               ┃   %index.next.1 = add nuw i64 %index, 32              127
160   %niter.next.1 = add i64 %niter, 2                    ┃   %niter.next.1 = add i64 %niter, 2                   128
161   %niter.ncmp.1 = icmp eq i64 %niter.next.1, %unroll_… ┃   %niter.ncmp.1 = icmp eq i64 %niter.next.1, %unroll_…129
162   br i1 %niter.ncmp.1, label %middle.block.unr-lcssa,… ┃   br i1 %niter.ncmp.1, label %middle.block.unr-lcssa,…130
163                                                        ┃                                                       131
164 middle.block.unr-lcssa:                           ; p… ┃ middle.block.unr-lcssa:                           ; p…132
165   %index.unr = phi i64 [ 0, %vector.ph ], [ %index.ne… ┃   %index.unr = phi i64 [ 0, %vector.ph ], [ %index.ne…133
166   %lcmp.mod.not = icmp eq i64 %xtraiter, 0             ┃   %lcmp.mod.not = icmp eq i64 %xtraiter, 0            134
167   br i1 %lcmp.mod.not, label %middle.block, label %ve… ┃   br i1 %lcmp.mod.not, label %middle.block, label %ve…135
168                                                        ┃                                                       136
169 vector.body.epil.preheader:                       ; p… ┃ vector.body.epil.preheader:                       ; p…137
170   %81 = getelementptr inbounds i64, i64* %arrayptr29,…⟪╋⟫  %76 = getelementptr inbounds i64, i64* %arrayptr8, …138
171   %82 = bitcast i64* %81 to <4 x i64>*                ⟪╋⟫  %77 = bitcast i64* %76 to <4 x i64>*                139
172   %wide.load.epil = load <4 x i64>, <4 x i64>* %82, a…⟪╋⟫  %wide.load.epil = load <4 x i64>, <4 x i64>* %77, a…140
173   %83 = getelementptr inbounds i64, i64* %81, i64 4   ⟪╋⟫  %78 = getelementptr inbounds i64, i64* %76, i64 4   141
174   %84 = bitcast i64* %83 to <4 x i64>*                ⟪╋⟫  %79 = bitcast i64* %78 to <4 x i64>*                142
175   %wide.load66.epil = load <4 x i64>, <4 x i64>* %84,…⟪╋⟫  %wide.load13.epil = load <4 x i64>, <4 x i64>* %79,…143
176   %85 = getelementptr inbounds i64, i64* %81, i64 8   ⟪╋⟫  %80 = getelementptr inbounds i64, i64* %76, i64 8   144
177   %86 = bitcast i64* %85 to <4 x i64>*                ⟪╋⟫  %81 = bitcast i64* %80 to <4 x i64>*                145
178   %wide.load67.epil = load <4 x i64>, <4 x i64>* %86,…⟪╋⟫  %wide.load14.epil = load <4 x i64>, <4 x i64>* %81,…146
179   %87 = getelementptr inbounds i64, i64* %81, i64 12  ⟪╋⟫  %82 = getelementptr inbounds i64, i64* %76, i64 12  147
180   %88 = bitcast i64* %87 to <4 x i64>*                ⟪╋⟫  %83 = bitcast i64* %82 to <4 x i64>*                148
181   %wide.load68.epil = load <4 x i64>, <4 x i64>* %88,…⟪╋⟫  %wide.load15.epil = load <4 x i64>, <4 x i64>* %83,…149
182   %89 = mul <4 x i64> %wide.load.epil, %broadcast.spl…⟪╋⟫  %84 = mul <4 x i64> %wide.load.epil, %broadcast.spl…150
183   %90 = mul <4 x i64> %wide.load66.epil, %broadcast.s…⟪╋⟫  %85 = mul <4 x i64> %wide.load13.epil, %broadcast.s…151
184   %91 = mul <4 x i64> %wide.load67.epil, %broadcast.s…⟪╋⟫  %86 = mul <4 x i64> %wide.load14.epil, %broadcast.s…152
185   %92 = mul <4 x i64> %wide.load68.epil, %broadcast.s…⟪╋⟫  %87 = mul <4 x i64> %wide.load15.epil, %broadcast.s…153
186   %93 = getelementptr inbounds i64, i64* %arrayptr143…⟪╋⟫  %88 = getelementptr inbounds i64, i64* %arrayptr29,…154
187   %94 = bitcast i64* %93 to <4 x i64>*                ⟪╋⟫  %89 = bitcast i64* %88 to <4 x i64>*                155
188   %wide.load75.epil = load <4 x i64>, <4 x i64>* %94,…⟪╋⟫  %wide.load22.epil = load <4 x i64>, <4 x i64>* %89,…156
189   %95 = getelementptr inbounds i64, i64* %93, i64 4   ⟪╋⟫  %90 = getelementptr inbounds i64, i64* %88, i64 4   157
190   %96 = bitcast i64* %95 to <4 x i64>*                ⟪╋⟫  %91 = bitcast i64* %90 to <4 x i64>*                158
191   %wide.load76.epil = load <4 x i64>, <4 x i64>* %96,…⟪╋⟫  %wide.load23.epil = load <4 x i64>, <4 x i64>* %91,…159
192   %97 = getelementptr inbounds i64, i64* %93, i64 8   ⟪╋⟫  %92 = getelementptr inbounds i64, i64* %88, i64 8   160
193   %98 = bitcast i64* %97 to <4 x i64>*                ⟪╋⟫  %93 = bitcast i64* %92 to <4 x i64>*                161
194   %wide.load77.epil = load <4 x i64>, <4 x i64>* %98,…⟪╋⟫  %wide.load24.epil = load <4 x i64>, <4 x i64>* %93,…162
195   %99 = getelementptr inbounds i64, i64* %93, i64 12  ⟪╋⟫  %94 = getelementptr inbounds i64, i64* %88, i64 12  163
196   %100 = bitcast i64* %99 to <4 x i64>*               ⟪╋⟫  %95 = bitcast i64* %94 to <4 x i64>*                164
197   %wide.load78.epil = load <4 x i64>, <4 x i64>* %100…⟪╋⟫  %wide.load25.epil = load <4 x i64>, <4 x i64>* %95,…165
198   %101 = add <4 x i64> %wide.load75.epil, %89         ⟪╋⟫  %96 = add <4 x i64> %wide.load22.epil, %84          166
199   %102 = add <4 x i64> %wide.load76.epil, %90         ⟪╋⟫  %97 = add <4 x i64> %wide.load23.epil, %85          167
200   %103 = add <4 x i64> %wide.load77.epil, %91         ⟪╋⟫  %98 = add <4 x i64> %wide.load24.epil, %86          168
201   %104 = add <4 x i64> %wide.load78.epil, %92         ⟪╋⟫  %99 = add <4 x i64> %wide.load25.epil, %87          169
202   %105 = getelementptr inbounds i64, i64* %arrayptr23…⟪╋⟫  %100 = getelementptr inbounds i64, i64* %arrayptr51…170
203   %106 = bitcast i64* %105 to <4 x i64>*              ⟪╋⟫  %101 = bitcast i64* %100 to <4 x i64>*              171
204   store <4 x i64> %101, <4 x i64>* %106, align 8      ⟪╋⟫  store <4 x i64> %96, <4 x i64>* %101, align 8       172
205   %107 = getelementptr inbounds i64, i64* %105, i64 4 ⟪╋⟫  %102 = getelementptr inbounds i64, i64* %100, i64 4 173
206   %108 = bitcast i64* %107 to <4 x i64>*              ⟪╋⟫  %103 = bitcast i64* %102 to <4 x i64>*              174
207   store <4 x i64> %102, <4 x i64>* %108, align 8      ⟪╋⟫  store <4 x i64> %97, <4 x i64>* %103, align 8       175
208   %109 = getelementptr inbounds i64, i64* %105, i64 8 ⟪╋⟫  %104 = getelementptr inbounds i64, i64* %100, i64 8 176
209   %110 = bitcast i64* %109 to <4 x i64>*              ⟪╋⟫  %105 = bitcast i64* %104 to <4 x i64>*              177
210   store <4 x i64> %103, <4 x i64>* %110, align 8      ⟪╋⟫  store <4 x i64> %98, <4 x i64>* %105, align 8       178
211   %111 = getelementptr inbounds i64, i64* %105, i64 1…⟪╋⟫  %106 = getelementptr inbounds i64, i64* %100, i64 1…179
212   %112 = bitcast i64* %111 to <4 x i64>*              ⟪╋⟫  %107 = bitcast i64* %106 to <4 x i64>*              180
213   store <4 x i64> %104, <4 x i64>* %112, align 8      ⟪╋⟫  store <4 x i64> %99, <4 x i64>* %107, align 8       181
214   br label %middle.block                               ┃   br label %middle.block                              182
215                                                        ┃                                                       183
216 middle.block:                                     ; p… ┃ middle.block:                                     ; p…184
217   %cmp.n = icmp eq i64 %exit.mainloop.at, %n.vec      ⟪╋⟫  %cmp.n = icmp eq i64 %arraylen, %n.vec              185
218   br i1 %cmp.n, label %main.exit.selector, label %sca…⟪┫                                                       
219                                                       ⟪┫                                                       
220 scalar.ph:                                        ; p…⟪┫                                                       
221   %bc.resume.val = phi i64 [ %ind.end, %middle.block …⟪┫                                                       
222   br label %idxend21                                  ⟪┫                                                       
223                                                       ⟪┫                                                       
224 L31:                                              ; p…⟪┫                                                       
225   ret void                                            ⟪┫                                                       
226                                                       ⟪┫                                                       
227 oob:                                              ; p…⟪┫                                                       
228   %errorbox = alloca i64, align 8                     ⟪┫                                                       
229   store i64 %value_phi3.postloop, i64* %errorbox, ali…⟪┫                                                       
230   call void @ijl_bounds_error_ints({}* %2, i64* nonnu…⟪┫                                                       
231   unreachable                                         ⟪┫                                                       
232                                                       ⟪┫                                                       
233 oob10:                                            ; p…⟪┫                                                       
234   %errorbox11 = alloca i64, align 8                   ⟪┫                                                       
235   store i64 %value_phi3.postloop, i64* %errorbox11, a…⟪┫                                                       
236   call void @ijl_bounds_error_ints({}* %3, i64* nonnu…⟪┫                                                       
237   unreachable                                         ⟪┫                                                       
238                                                       ⟪┫                                                       
239 oob19:                                            ; p…⟪┫                                                       
240   %errorbox20 = alloca i64, align 8                   ⟪┫                                                       
241   store i64 %value_phi3.postloop, i64* %errorbox20, a…⟪┫                                                       
242   call void @ijl_bounds_error_ints({}* %0, i64* nonnu…⟪┫                                                       
243   unreachable                                         ⟪┫                                                       
244                                                       ⟪┫                                                       
245 idxend21:                                         ; p…⟪┫                                                       
246   %value_phi3 = phi i64 [ %119, %idxend21 ], [ %bc.re…⟪┫                                                       
247   %113 = add nsw i64 %value_phi3, -1                  ⟪┫                                                       
248   %114 = getelementptr inbounds i64, i64* %arrayptr29…⟪┫                                                       
249   %arrayref = load i64, i64* %114, align 8            ⟪┫                                                       
250   %115 = mul i64 %arrayref, %1                        ⟪┫                                                       
251   %116 = getelementptr inbounds i64, i64* %arrayptr14…⟪┫                                                       
252   %arrayref15 = load i64, i64* %116, align 8          ⟪┫                                                       
253   %117 = add i64 %arrayref15, %115                    ⟪┫                                                       
254   %118 = getelementptr inbounds i64, i64* %arrayptr23…⟪┫                                                       
255   store i64 %117, i64* %118, align 8                  ⟪┫                                                       
256   %119 = add nuw nsw i64 %value_phi3, 1               ⟪┫                                                       
257   %.not51 = icmp ult i64 %value_phi3, %exit.mainloop.…⟪┫                                                       
258   br i1 %.not51, label %idxend21, label %main.exit.se…⟪┫                                                       
259                                                       ⟪┫                                                       
260 main.exit.selector:                               ; p…⟪┫                                                       
261   %value_phi3.lcssa = phi i64 [ %exit.mainloop.at, %m…⟪┫                                                       
262   %.lcssa = phi i64 [ %ind.end, %middle.block ], [ %1…⟪┫                                                       
263   %120 = icmp ult i64 %value_phi3.lcssa, %arraylen    ⟪┫                                                       
264   br i1 %120, label %main.pseudo.exit, label %L31     ⟪┫                                                       
265                                                       ⟪┫                                                       
266 main.pseudo.exit:                                 ; p…⟪┫                                                       
267   %value_phi3.copy = phi i64 [ 1, %L13.preheader ], […⟪┫                                                       
268   br label %L13.postloop                              ⟪┫                                                       
269                                                       ⟪┫                                                       
270 L13.postloop:                                     ; p…⟪┫                                                       
271   %value_phi3.postloop = phi i64 [ %127, %idxend21.po…⟪┫                                                       
272   %121 = add i64 %value_phi3.postloop, -1             ⟪┫                                                       
273   %inbounds.postloop = icmp ult i64 %121, %arraylen6  ⟪┫                                                       
274   br i1 %inbounds.postloop, label %idxend.postloop, l…⟪┫                                                       
                                                           ┣⟫  br i1 %cmp.n, label %L32, label %scalar.ph          186
275                                                        ┃                                                       187
276 idxend.postloop:                                  ; p…⟪┫                                                       
277   %inbounds9.postloop = icmp ult i64 %121, %arraylen8 ⟪┫                                                       
278   br i1 %inbounds9.postloop, label %idxend12.postloop…⟪┫                                                       
                                                           ┣⟫scalar.ph:                                        ; p…188
                                                           ┣⟫  %bc.resume.val = phi i64 [ %n.vec, %middle.block ],…189
                                                           ┣⟫  br label %L12                                       190
279                                                        ┃                                                       191
280 idxend12.postloop:                                ; p…⟪┫                                                       
281   %inbounds18.postloop = icmp ult i64 %121, %arraylen ⟪┫                                                       
282   br i1 %inbounds18.postloop, label %idxend21.postloo…⟪┫                                                       
                                                           ┣⟫L12:                                              ; p…192
                                                           ┣⟫  %value_phi12 = phi i64 [ %bc.resume.val, %scalar.ph…193
                                                           ┣⟫  %108 = getelementptr inbounds i64, i64* %arrayptr8,…194
                                                           ┣⟫  %arrayref = load i64, i64* %108, align 8            195
                                                           ┣⟫  %109 = mul i64 %arrayref, %1                        196
                                                           ┣⟫  %110 = getelementptr inbounds i64, i64* %arrayptr29…197
                                                           ┣⟫  %arrayref3 = load i64, i64* %110, align 8           198
                                                           ┣⟫  %111 = add i64 %arrayref3, %109                     199
                                                           ┣⟫  %112 = getelementptr inbounds i64, i64* %arrayptr51…200
                                                           ┣⟫  store i64 %111, i64* %112, align 8                  201
                                                           ┣⟫  %113 = add nuw nsw i64 %value_phi12, 1              202
                                                           ┣⟫  %exitcond.not = icmp eq i64 %113, %arraylen         203
                                                           ┣⟫  br i1 %exitcond.not, label %L32, label %L12         204
283                                                        ┃                                                       205
284 idxend21.postloop:                                ; p…⟪┫                                                       
285   %122 = getelementptr inbounds i64, i64* %arrayptr29…⟪┫                                                       
286   %arrayref.postloop = load i64, i64* %122, align 8   ⟪┫                                                       
287   %123 = mul i64 %arrayref.postloop, %1               ⟪┫                                                       
288   %124 = getelementptr inbounds i64, i64* %arrayptr14…⟪┫                                                       
289   %arrayref15.postloop = load i64, i64* %124, align 8 ⟪┫                                                       
290   %125 = add i64 %arrayref15.postloop, %123           ⟪┫                                                       
291   %126 = getelementptr inbounds i64, i64* %arrayptr23…⟪┫                                                       
292   store i64 %125, i64* %126, align 8                  ⟪┫                                                       
293   %.not.not32.postloop = icmp eq i64 %value_phi3.post…⟪┫                                                       
294   %127 = add nuw nsw i64 %value_phi3.postloop, 1      ⟪┫                                                       
295   br i1 %.not.not32.postloop, label %L31, label %L13.…⟪┫                                                       
                                                           ┣⟫L32:                                              ; p…206
                                                           ┣⟫  ret void                                            207
296 }                                                      ┃ }                                                     208
297                                                        ┃                                                       209