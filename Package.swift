// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

// Try and find the target architecture from the environment.
let targetArchitecture = ProcessInfo.processInfo.environment["ARCHS"] ?? ""
let isX86 = targetArchitecture.contains("x86_64") || targetArchitecture.contains("i386") || targetArchitecture.contains("amd64")

let faissTarget: Target
//if isX86 {
//    faissTarget = .target(
//        name: "CPPFaiss",
//        dependencies: ["OpenMP"],
//        path: ".",
//        exclude: [
//            // Remove standard GPU Support
//            "faiss/gpu_metal",
//            
//            // Remove python bridge since it is not needed in Swift.
//            "faiss/python",
//            
//            // Remove documentation
//            "faiss/svs",
//            "faiss/docs",
//            
//            // Remove non-source files that would be included as a resource
//            "faiss/CMakeLists.txt",
//            "faiss/cppcontrib/docker_dev/Dockerfile",
//        ],
//        sources: [
//            "faiss/",
//        ],
//        resources: [
//            .process("faiss/gpu_metal/MetalDistance.metal")
//        ],
//        publicHeadersPath: "faiss",
//        cxxSettings: [
//            // headerSearchPath is relative to the target root ("."), so "."
//            // puts the package root on the search path and FAISS's
//            // `<faiss/impl/...>` includes resolve to faiss/impl/...
//            // ("faiss/" would only resolve bare `<impl/...>` includes).
//            .headerSearchPath("."),
//            .define("FINTEGER", to: "int"),
//            // FAISS v1.14.3 requires C++20 (concepts/requires-expressions,
//            // template-parameter lambdas). CMake sets CMAKE_CXX_STANDARD 20.
//            .unsafeFlags(["-std=c++20"])
//            
//        ],
//        linkerSettings: [
//            .linkedFramework("Accelerate")
//        ],
//    )
//} else {
    faissTarget = .target(
        name: "CPPFaiss",
        dependencies: ["OpenMP"],
        path: ".",
        exclude: [
            // Python bridge (optional; not needed for the Swift backend).
            "faiss/gpu_metal/MetalPythonBridge.h",
            "faiss/gpu_metal/MetalPythonBridge.mm",
            // Upstream test sources + build glue would otherwise be treated
            // as sources/resources by SwiftPM.
            "faiss/gpu_metal/test",
            "faiss/gpu_metal/CMakeLists.txt",
            // The shader is declared explicitly as a resource below; exclude
            // it from the source list so the two rules don't collide.
            "faiss/gpu_metal/MetalDistance.metal",
            
            // GPU Directories
            "faiss/gpu",
            // Non-cpp source directories
            "faiss/python",
            "faiss/svs",
            "faiss/docs",
            // Non-source files inside the compiled tree that SwiftPM would
            // otherwise treat as resources.
            "faiss/CMakeLists.txt",
            "faiss/cppcontrib/docker_dev/Dockerfile",
            // x86 AVX2/AVX512 and ARM SVE translation units (arm64 uses the
            // generic/NEON path compiled from the shared .cpp files).
            "faiss/impl/approx_topk/avx2.cpp",
            "faiss/impl/binary_hamming/avx2.cpp",
            "faiss/impl/binary_hamming/avx512.cpp",
            "faiss/impl/fast_scan/impl-avx2.cpp",
            "faiss/impl/fast_scan/impl-avx512.cpp",
            "faiss/impl/hnsw/avx2.cpp",
            "faiss/impl/hnsw/avx512.cpp",
            "faiss/impl/pq_code_distance/avx2.cpp",
            "faiss/impl/pq_code_distance/avx512.cpp",
            "faiss/impl/pq_code_distance/pq_code_distance-sve.cpp",
            "faiss/impl/scalar_quantizer/sq-avx2.cpp",
            "faiss/impl/scalar_quantizer/sq-avx512-spr.cpp",
            "faiss/impl/scalar_quantizer/sq-avx512.cpp",
            "faiss/utils/distances_fused/avx512.cpp",
            "faiss/utils/hamming_distance/hamming_avx2.cpp",
            "faiss/utils/hamming_distance/hamming_avx512.cpp",
            "faiss/utils/hamming_distance/hamming_avx512_spr.cpp",
            "faiss/utils/simd_impl/distances_arm_sve.cpp",
            "faiss/utils/simd_impl/distances_avx2.cpp",
            "faiss/utils/simd_impl/distances_avx512.cpp",
            "faiss/utils/simd_impl/partitioning_avx2.cpp",
            "faiss/utils/simd_impl/rabitq_avx2.cpp",
            "faiss/utils/simd_impl/rabitq_avx512.cpp",
            "faiss/utils/simd_impl/rabitq_avx512_spr.cpp",
            "faiss/utils/simd_impl/super_kmeans_kernels_avx2.cpp",
            "faiss/utils/simd_impl/super_kmeans_kernels_avx512.cpp"
        ],
        sources: [
            "faiss/",
        ],
        resources: [
            .process("faiss/gpu_metal/MetalDistance.metal")
        ],
        publicHeadersPath: "faiss",
        cxxSettings: [
            // headerSearchPath is relative to the target root ("."), so "."
            // puts the package root on the search path and FAISS's
            // `<faiss/impl/...>` includes resolve to faiss/impl/...
            // ("faiss/" would only resolve bare `<impl/...>` includes).
            .headerSearchPath("."),
            .define("FINTEGER", to: "int"),
            // NEON is mandatory on arm64; CMake defines this for the main
            // faiss target so simdlib_dispatch.h pulls in simdlib_neon.h.
                .define("COMPILE_SIMD_ARM_NEON", .when(platforms: [.macOS, .iOS])),
            // FAISS v1.14.3 requires C++20 (concepts/requires-expressions,
            // template-parameter lambdas). CMake sets CMAKE_CXX_STANDARD 20.
                .unsafeFlags(["-std=c++20"]),
            // MetalKernels.mm uses this as @(FAISS_METALLIB_BUILD_PATH), so
            // the macro must expand to a C string literal. CMake defines it
            // as FAISS_METALLIB_BUILD_PATH="<path>"; the SwiftPM equivalent
            // of "empty" is the literal "" (escaped here), not an empty token
            // — `to: ""` would expand to `@()` and fail to compile. Empty is
            // fine: the loader falls through to FAISS_METALLIB_PATH (set by
            // the smoke entry / the owner's Swift code).
                .define("FAISS_METALLIB_BUILD_PATH", to: "\"\""),
            // gpu_metal is compiled WITHOUT ARC, matching upstream's CMake
            // (its CMakeLists sets only OBJCXX_STANDARD 17 and passes no
            // -fobjc-arc). Under ARC, MetalIndexIVFFlat.mm's
            // `id<MTLBuffer>&` out-params get an implicit __autoreleasing
            // pointee that won't bind to the callers' __strong ivars (a hard
            // error on this clang). MRC has no ownership qualifiers so those
            // references bind cleanly; the `__bridge` casts are accepted as
            // no-ops under MRC.
                .unsafeFlags(["-std=c++20", "-fno-objc-arc"])
            
        ],
        linkerSettings: [
            .linkedFramework("Metal"),
            .linkedFramework("Accelerate")
        ],
    )

//}




let package = Package(
    name: "faiss",
    // Declare modern deployment targets so SwiftPM compiles the bundled
    // MetalDistance.metal resource at a recent Metal Shading Language
    // revision. The shader binds 64-bit integer buffers (`device long*`
    // for IDs), which are only legal in MSL 2.3+ (macOS 11 / iOS 14). With
    // no platforms declared, SwiftPM falls back to a very old macOS default
    // and the Metal compiler rejects the `long` buffer arguments — the
    // CMake path avoids this because `xcrun metal` defaults to the SDK's
    // latest MSL version.
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "CPPFaiss", targets: ["CPPFaiss"])
    ],
    targets: [
        .binaryTarget(
            name: "OpenMP",
            url: "https://github.com/impel-intelligence/openmp-mobile/releases/download/v21.1.8/openmp.xcframework.zip",
            checksum: "2f93a8273d648ab7b6d2c72c11a1684a8e63e0a1e6e6f2a326dae882d7acc20f"
        ),
        faissTarget
    ],
    cxxLanguageStandard: .cxx20
)
