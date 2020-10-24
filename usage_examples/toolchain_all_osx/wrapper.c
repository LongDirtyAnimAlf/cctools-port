#ifndef TARGET_CPU
#define TARGET_CPU "x86_64"
#endif

#ifndef OS_VER_MIN
#define OS_VER_MIN "4.2"
#endif

#ifndef SDK_DIR
#define SDK_DIR ""
#endif

#define _GNU_SOURCE

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stddef.h>
#include <unistd.h>
#include <limits.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif

#if defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__DragonFly__)
#include <sys/sysctl.h>
#endif

#ifdef __OpenBSD__
#include <sys/user.h>

#endif

#if defined(WINDOWS) || defined(_WIN32) || defined(__CYGWIN__)
#include <windows.h>
#endif

int fileExists (char *filename)
{
  struct stat info;
  return (stat (filename, &info) == 0);
}

int dirExists(const char *path)
{
    struct stat info;

    if(stat( path, &info ) != 0)
        return 0;
    else if(info.st_mode & S_IFDIR)
        return 1;
    else
        return 0;
}

char *get_executable_path(char *epath, size_t buflen)
{
    char *p;
#ifdef __APPLE__
    unsigned int l = buflen;
    if (_NSGetExecutablePath(epath, &l) != 0) return NULL;
#elif defined(__FreeBSD__) || defined(__DragonFly__)
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PATHNAME, -1 };
    size_t l = buflen;
    if (sysctl(mib, 4, epath, &l, NULL, 0) != 0) return NULL;
#elif defined(__OpenBSD__)
    int mib[4];
    char **argv;
    size_t len;
    size_t l;
    const char *comm;
    int ok = 0;
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROC_ARGS;
    mib[2] = getpid();
    mib[3] = KERN_PROC_ARGV;
    if (sysctl(mib, 4, NULL, &len, NULL, 0) < 0)
        abort();
    if (!(argv = malloc(len)))
        abort();
    if (sysctl(mib, 4, argv, &len, NULL, 0) < 0)
        abort();
    comm = argv[0];
    if (*comm == '/' || *comm == '.')
    {
        char *rpath;
        if ((rpath = realpath(comm, NULL)))
        {
            strlcpy(epath, rpath, buflen);
            free(rpath);
            ok = 1;
        }
    }
    else
    {
        char *sp;
        char *xpath = strdup(getenv("PATH"));
        char *path = strtok_r(xpath, ":", &sp);
        struct stat st;
        if (!xpath)
            abort();
        while (path)
        {
            snprintf(epath, buflen, "%s/%s", path, comm);
            if (!stat(epath, &st) && (st.st_mode & S_IXUSR))
	    {
                ok = 1;
                break;
            }
            path = strtok_r(NULL, ":", &sp);
        }
        free(xpath);
    }
    free(argv);
    if (!ok) return NULL;
    l = strlen(epath);
#elif defined(WINDOWS) || defined(_WIN32) || defined(__CYGWIN__)
  char full_path[MAX_PATH];
  unsigned int l = 0;
  l = GetModuleFileName(NULL, full_path, MAX_PATH);
  p = strchr(full_path, '\\');
  while (p) {
    *p = '/';
    p  = strchr(full_path, '\\');
  }

  p = strchr(full_path, ':');
  if (p)
    *p = '/';

  snprintf(epath, buflen, "%c%s%c%s", '/', "cygdrive", '/', full_path);    
#else
    ssize_t l = readlink("/proc/self/exe", epath, buflen - 1);
    if (l > 0) epath[l] = '\0';
#endif
    if (l <= 0) return NULL;
    epath[buflen - 1] = '\0';
    p = strrchr(epath, '/');
    if (p) *p = '\0';
    return epath;
}

char *get_filename(char *str)
{
    char *p = strrchr(str, '/');
    return p ? &p[1] : str;
}

void target_info(char *argv[], char **triple, char **compiler)
{
    char *p = get_filename(argv[0]);
    char *x = strrchr(p, '-');
    if (!x) abort();
    *compiler = &x[1];
    *x = '\0';
    *triple = p;
}

void env(char **p, const char *name, char *fallback)
{
    char *ev = getenv(name);
    if (ev) { *p = ev; return; }
    *p = fallback;
}

int main(int argc, char *argv[])
{
    char **args = alloca(sizeof(char*) * (argc+15));
    int i, j;

    char execpath[PATH_MAX+1];
    char sdkpath[PATH_MAX+1];
    char compilerpath[PATH_MAX+1];
    char codesign_allocate[64];
    char osvermin[64];

    char *compiler;
    char *target;

    char *sdk;
    char *cpu;
    char *osmin;


    if (!get_executable_path(execpath, sizeof(execpath))) abort();

    target_info(argv, &target, &compiler);

    snprintf(compilerpath, sizeof(compilerpath), "%s/%s", execpath, compiler);


    if (!fileExists(compilerpath))
    {
        snprintf(compilerpath, sizeof(compilerpath), "%s", compiler);
    }

    //snprintf(sdkpath, sizeof(sdkpath), "%s/../SDK", execpath);
    snprintf(sdkpath, sizeof(sdkpath), "%s/../SDK/" SDK_DIR, execpath);

    // Dedicated libs

    if (!dirExists(sdkpath))
    {
        snprintf(sdkpath, sizeof(sdkpath), "%s/../../lib/x86_64-darwin/" SDK_DIR, execpath);
    }
    if (!dirExists(sdkpath))
    {
        snprintf(sdkpath, sizeof(sdkpath), "%s/../../../lib/x86_64-darwin/" SDK_DIR, execpath);
    }
    
    if (!dirExists(sdkpath))
    {
        snprintf(sdkpath, sizeof(sdkpath), "%s/../../lib/x86_64-darwin/SDK", execpath);
    }
    if (!dirExists(sdkpath))
    {
        snprintf(sdkpath, sizeof(sdkpath), "%s/../../lib/x86_64-darwin", execpath);
    }
    
    if (!dirExists(sdkpath))
    {
        snprintf(sdkpath, sizeof(sdkpath), "%s/../../../lib/x86_64-darwin/SDK", execpath);
    }
    if (!dirExists(sdkpath))
    {
        snprintf(sdkpath, sizeof(sdkpath), "%s/../../../lib/x86_64-darwin", execpath);
    }

    // Universal libs

    if (!dirExists(sdkpath))
    {
        snprintf(sdkpath, sizeof(sdkpath), "%s/../../lib/all-darwin/" SDK_DIR, execpath);
    }
    if (!dirExists(sdkpath))
    {
        snprintf(sdkpath, sizeof(sdkpath), "%s/../../../lib/all-darwin/" SDK_DIR, execpath);
    }
    
    if (!dirExists(sdkpath))
    {
        snprintf(sdkpath, sizeof(sdkpath), "%s/../../lib/all-darwin/SDK", execpath);
    }
    if (!dirExists(sdkpath))
    {
        snprintf(sdkpath, sizeof(sdkpath), "%s/../../lib/all-darwin", execpath);
    }
    
    if (!dirExists(sdkpath))
    {
        snprintf(sdkpath, sizeof(sdkpath), "%s/../../../lib/all-darwin/SDK", execpath);
    }
    if (!dirExists(sdkpath))
    {
        snprintf(sdkpath, sizeof(sdkpath), "%s/../../../lib/all-darwin", execpath);
    }

    
    snprintf(codesign_allocate, sizeof(codesign_allocate),
             "%s-codesign_allocate", target);

    setenv("CODESIGN_ALLOCATE", codesign_allocate, 1);
    setenv("OSX_FAKE_CODE_SIGN", "1", 1);

    env(&sdk, "OSX_SDK_SYSROOT", sdkpath);
    env(&cpu, "OSX_TARGET_CPU", TARGET_CPU);

    env(&osmin, "MACOSX_DEPLOYMENT_TARGET", OS_VER_MIN);
    unsetenv("MACOSX_DEPLOYMENT_TARGET");

    snprintf(osvermin, sizeof(osvermin), "-mmacosx-version-min=%s", osmin);

    for (i = 1; i < argc; ++i)
    {
        if (!strcmp(argv[i], "-arch"))
        {
            cpu = NULL;
            break;
        }
    }

    i = 0;

    args[i++] = compilerpath;
    args[i++] = "-target";
    args[i++] = target;
    args[i++] = "-isysroot";
    args[i++] = sdk;

    if (cpu)
    {
        args[i++] = "-arch";
        args[i++] = cpu;
    }

    args[i++] = osvermin;
    args[i++] = "-mlinker-version=540";

    args[i++] = "-Wno-unused-command-line-argument";
    args[i++] = "-Wno-overriding-t-option";

    for (j = 1; j < argc; ++i, ++j)
        args[i] = argv[j];

    args[i] = NULL;

    setenv("COMPILER_PATH", execpath, 1);
    execvp(compilerpath, args);

    fprintf(stderr, "cannot invoke compiler!\n");
    return 1;
}
