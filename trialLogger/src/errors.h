#ifndef __ERRORS_H_
#define __ERRORS_H_

#include <stdio.h>  /* printf(), etc */
#include <stdlib.h> /* For EXIT_FAILURE, EXIT_SUCCESS, malloc etc. */
#include <errno.h>  /* ERROR Number Definitions  */
#include <string.h> /* String operations */

#ifdef _WIN32
	#include <Windows.h>
#else
	#include <unistd.h>  /* UNIX Standard Definitions: usleep(), read(), write() etc. */
#endif

/*
 * Define a macro that can be used for diagnostic output from
 * examples. When compiled -DDEBUG, it results in calling printf
 * with the specified argument list. When DEBUG is not defined, it
 * expands to nothing.
 */
#ifdef DEBUG
	# define DPRINTF(arg) logInfo arg
#else
	# define DPRINTF(arg) (void)0
#endif

// avoid gcc -Wformat-truncation [...] warns
#define snprintf_nowarn(...) (snprintf(__VA_ARGS__) < 0 ? abort() : (void)0)

// MEX API Is Not Thread Safe:
// https://www.mathworks.com/help/matlab/matlab_external/mex-api-is-not-thread-safe.html
#ifdef MATLAB_MEX_FILE
  #define logInfo(...) (void)0
  #define logError(...) fprintf(stderr, __VA_ARGS__)
#else
  #define logInfo printf
  #define logError(...) fprintf(stderr, __VA_ARGS__)
#endif

/*
 * NOTE: the "do {" ... "} while (0);" bracketing around the macros
 * allows the err_abort and errno_abort macros to be used as if they
 * were function calls, even in contexts where a trailing ";" would
 * generate a null statement. For example,
 *
 *      if (status != 0)
 *          err_abort (status, "message");
 *      else
 *          return status;
 *
 * will not compile if err_abort is a macro ending with "}", because
 * C does not expect a ";" to follow the "}". Because C does expect
 * a ";" following the ")" in the do...while construct, err_abort and
 * errno_abort can be used as if they were function calls.
 */
#ifdef MATLAB_MEX_FILE
	#define err_print(code, text) \
		char str[200]; \
		snprintf_nowarn(str, 200, "%s (errorcode = %d) at \"%s\":%d : %s\n", \
				text, code, __FILE__, __LINE__, strerror (code)); \
		mexErrMsgIdAndTxt("MATLAB:udpMexReceiver", str)
#else
	#define err_print(code, text) \
		fprintf(stderr, "%s (errorcode = %d) at \"%s\":%d : %s\n", \
				text, code, __FILE__, __LINE__, strerror (code))
#endif

#ifdef MATLAB_MEX_FILE
	#define err_abort(code, text) do { \
		err_print(code, text); \
		mexUnlock(); \
		} while (0)
#else
	#define err_abort(code, text) do { \
		err_print(code, text); \
		abort (); \
		} while (0)
#endif

#ifdef MATLAB_MEX_FILE
	#define errno_print(text) \
		char str[200]; \
		snprintf_nowarn(str, 200, "%s (errno = %d) at \"%s\":%d : %s\n", \
			text, errno, __FILE__, __LINE__, strerror(errno)) ; \
		mexErrMsgIdAndTxt("MATLAB:udpMexReceiver", str)
#else
	#define errno_print(text) \
		fprintf(stderr, "%s (errno = %d) at \"%s\":%d : %s\n", \
				text, errno, __FILE__, __LINE__, strerror(errno))
#endif

#ifdef MATLAB_MEX_FILE
	#define errno_abort(text) do { \
		errno_print(text); \
		mexUnlock(); \
		} while (0)
#else
	#define errno_abort(text) do { \
		errno_print(text); \
		abort (); \
		} while (0)
#endif

#endif /* __ERRORS_H_ */
