#include "ds4.h"

#include <inttypes.h>
#include <mach/mach.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/sysctl.h>

enum {
    FARO_BLOCK_SIZE = 6,
    FARO_CONTEXT_SIZE = 1024,
    FARO_CACHE_EXPERTS = 1521,
};

static const char *k_synthetic_prompt =
    "Write a compact C function that returns the larger of two signed "
    "integers, followed by three simple assertions. Output code only.";

static uint64_t footprint_bytes(void) {
    task_vm_info_data_t info;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_VM_INFO,
                  (task_info_t)&info, &count) != KERN_SUCCESS) {
        return 0;
    }
    return (uint64_t)info.phys_footprint;
}

static uint64_t peak_rss_bytes(void) {
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) != 0) return 0;
    return (uint64_t)usage.ru_maxrss;
}

static uint64_t swap_used_bytes(void) {
    struct xsw_usage swap;
    size_t size = sizeof(swap);
    if (sysctlbyname("vm.swapusage", &swap, &size, NULL, 0) != 0) return 0;
    return (uint64_t)swap.xsu_used;
}

static const char *relation(bool equal) {
    return equal ? "MATCH" : "DIFFERENT";
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s OFFICIAL_MODEL.gguf\n", argv[0]);
        return 2;
    }

    setenv("FARO_GATE4C1_ORACLE_VERIFIER", "1", 1);
    setenv("DS4_DSPARK_VERIFY_SELECTED_PROFILE", "1", 1);
    ds4_engine_options options = {
        .model_path = argv[1],
        .backend = DS4_BACKEND_METAL,
        .context_size = FARO_CONTEXT_SIZE,
        .quality = false,
        .ssd_streaming = true,
        .ssd_streaming_cold = false,
        .ssd_streaming_cache_experts = FARO_CACHE_EXPERTS,
    };

    ds4_engine *engine = NULL;
    if (ds4_engine_open(&engine, &options) != 0 || !engine) {
        fputs("faro-reproducer: target open failed\n", stderr);
        return 1;
    }

    ds4_session *session = NULL;
    ds4_tokens prompt = {0};
    char err[512] = {0};
    int rc = 1;
    if (ds4_session_create(&session, engine, FARO_CONTEXT_SIZE) != 0 ||
        !session) {
        fputs("faro-reproducer: session creation failed\n", stderr);
        goto cleanup;
    }
    ds4_encode_chat_prompt(engine, NULL, k_synthetic_prompt,
                           DS4_THINK_NONE, &prompt);
    if (prompt.len <= 0 ||
        ds4_session_sync(session, &prompt, err, sizeof(err)) != 0) {
        fprintf(stderr, "faro-reproducer: bounded prefill failed: %s\n",
                err[0] ? err : "unknown error");
        goto cleanup;
    }

    ds4_oracle_verify_result warmup;
    if (ds4_session_oracle_verify_block(
            session, FARO_BLOCK_SIZE, false, false,
            &warmup, err, sizeof(err)) != 0) {
        fprintf(stderr, "faro-reproducer: warm-up failed: %s\n",
                err[0] ? err : "unknown error");
        goto cleanup;
    }

    ds4_oracle_verify_result result;
    if (ds4_session_oracle_verify_block(
            session, FARO_BLOCK_SIZE, false, true,
            &result, err, sizeof(err)) != 0) {
        fprintf(stderr, "faro-reproducer: measured run failed: %s\n",
                err[0] ? err : "unknown error");
        goto cleanup;
    }

    const uint64_t footprint = footprint_bytes();
    const uint64_t peak_rss = peak_rss_bytes();
    const uint64_t swap_used = swap_used_bytes();
    const bool oracle_valid =
        result.all_oracle_tokens_accepted &&
        result.committed_tokens == FARO_BLOCK_SIZE;
    const bool counters_match =
        result.compressor_count_mismatch_layers == 0u &&
        result.index_count_mismatch_layers == 0u;
    const bool state_differs =
        result.state_signature_checked &&
        result.raw_kv_signature_mismatch_layers > 0u &&
        result.attn_state_signature_mismatch_layers > 0u &&
        result.index_state_signature_mismatch_layers > 0u;
    const bool expert_dedup_visible =
        result.unique_experts > 0u &&
        result.unique_experts < result.expert_requests;
    const bool replay_exact =
        result.used_exact_commit_replay &&
        result.exact_replay_tokens == FARO_BLOCK_SIZE &&
        result.final_logits_max_abs == 0.0 &&
        result.final_logits_rmse == 0.0 &&
        result.final_argmax_equal &&
        result.continuation_equal &&
        result.rollback_ok;
    const bool memory_safe =
        footprint <= 24ull * 1024ull * 1024ull * 1024ull &&
        swap_used <= 3ull * 1024ull * 1024ull * 1024ull;

    puts("DS4 base commit: MATCH");
    printf("Oracle candidates: %s\n", oracle_valid ? "VALID" : "INVALID");
    printf("Frontier position: %s\n",
           relation(result.frontier_position_equal));
    printf("Compressor counters: %s\n", relation(counters_match));
    printf("Raw KV state: %s\n",
           relation(result.raw_kv_signature_mismatch_layers == 0u));
    printf("Attention compressor state: %s\n",
           relation(result.attn_state_signature_mismatch_layers == 0u));
    printf("Index compressor state: %s\n",
           relation(result.index_state_signature_mismatch_layers == 0u));
    printf("Replay-safe final logits: %s\n",
           replay_exact ? "EXACT MATCH" : "DIFFERENT");
    printf(
        "FARO_RESULT_JSON={\"schema_version\":1,"
        "\"base_commit\":\"54b36ed9ba42da31b24f2d1a5feb075c2475dbb1\","
        "\"block_size\":%u,\"oracle_candidates\":\"%s\","
        "\"frontier_position\":\"%s\",\"compressor_counters\":\"%s\","
        "\"raw_kv_state\":\"%s\","
        "\"attention_compressor_state\":\"%s\","
        "\"index_compressor_state\":\"%s\","
        "\"replay_safe_final_logits\":\"%s\","
        "\"raw_kv_mismatch_layers\":%u,"
        "\"attention_state_mismatch_layers\":%u,"
        "\"index_state_mismatch_layers\":%u,"
        "\"expert_requests\":%" PRIu64 ",\"unique_experts\":%" PRIu64 ","
        "\"cache_hits\":%" PRIu64 ",\"cache_misses\":%" PRIu64 ","
        "\"pread_bytes\":%" PRIu64 ",\"pread_ms\":%.6f,"
        "\"t_core_ms\":%.6f,\"t_verify_ms\":%.6f,"
        "\"t_verify_rollback_ms\":%.6f,\"t_replay_ms\":%.6f,"
        "\"t_safe_total_ms\":%.6f,\"footprint_bytes\":%" PRIu64 ","
        "\"peak_rss_bytes\":%" PRIu64 ",\"swap_used_bytes\":%" PRIu64 "}\n",
        result.block_size,
        oracle_valid ? "VALID" : "INVALID",
        result.frontier_position_equal ? "MATCH" : "DIFFERENT",
        counters_match ? "MATCH" : "DIFFERENT",
        result.raw_kv_signature_mismatch_layers == 0u ? "MATCH" : "DIFFERENT",
        result.attn_state_signature_mismatch_layers == 0u ?
            "MATCH" : "DIFFERENT",
        result.index_state_signature_mismatch_layers == 0u ?
            "MATCH" : "DIFFERENT",
        replay_exact ? "EXACT MATCH" : "DIFFERENT",
        result.raw_kv_signature_mismatch_layers,
        result.attn_state_signature_mismatch_layers,
        result.index_state_signature_mismatch_layers,
        result.expert_requests,
        result.unique_experts,
        result.cache_hits,
        result.cache_misses,
        result.pread_bytes,
        result.pread_ms,
        result.t_core_ms,
        result.t_verify_ms,
        result.t_verify_rollback_ms,
        result.replay_ms,
        result.t_safe_total_ms,
        footprint,
        peak_rss,
        swap_used);
    fflush(stdout);

    rc = oracle_valid && counters_match && expert_dedup_visible &&
         state_differs &&
         replay_exact && memory_safe ? 0 : 1;

cleanup:
    ds4_tokens_free(&prompt);
    ds4_session_free(session);
    ds4_engine_close(engine);
    return rc;
}
