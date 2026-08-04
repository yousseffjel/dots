/* See LICENSE file for copyright and license details. */

#define MAX(A, B)               ((A) > (B) ? (A) : (B))
#define MIN(A, B)               ((A) < (B) ? (A) : (B))
#define BETWEEN(X, A, B)        ((A) <= (X) && (X) <= (B))
#define LENGTH(X)               (sizeof (X) / sizeof (X)[0])

/* die() always exit()s. Telling the compiler so lets -Wformat check its
 * arguments (this caught a %u-applied-to-size_t bug) and stops static
 * analyzers treating every `if (!(p = malloc(..))) die(..);` as a path where
 * p may still be NULL afterwards. Attribute syntax is GNU/clang only. */
#if defined(__GNUC__) || defined(__clang__)
__attribute__((noreturn, format(printf, 1, 2)))
#endif
void die(const char *fmt, ...);
void *ecalloc(size_t nmemb, size_t size);
