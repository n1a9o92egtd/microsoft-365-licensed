#import "ms365Licensed.h"
#import <pthread.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import "fishhook.h"

#define DYLD_INTERPOSE(_replacment,_replacee) \
   __attribute__((used)) static struct{ const void* replacment; const void* replacee; } _interpose_##_replacee \
            __attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacment, (const void*)(unsigned long)&_replacee };

static uint64_t (*origIsSubscription)(uint16_t type) = NULL;
static uint64_t (*origIsSubscriptionToken)(uint16_t type) = NULL;

static uint64_t (*origMbuInAutomatedQTestMode)() = NULL;
static uint64_t (*origMbuInAutomatedQTestModeToken)() = NULL;

static uint64_t (*origMbuInAutomatedAssertMode)() = NULL;
static uint64_t (*origMbuInAutomatedAssertModeToken)() = NULL;

static uint64_t (*origMbuIsRetailDemoSKU)() = NULL;
static uint64_t (*origMbuIsRetailDemoSKUToken)() = NULL;

static uint64_t IsSubscriptionProxy(uint16_t type){
    return 1;
}

static uint64_t MbuInAutomatedQTestModeProxy(){
    return 1;
}

void *threadMSO30(void *arg) {
    int excel_mso30_framework_hooked = 0;
    int excel_mbuinstrument_framework_hooked = 0;
    for(;;) {
        const char* func = "_ZN3Mso9Licensing8Category14IsSubscriptionENSt3__18optionalINS1_15LicenseCategoryEEE";
        if(!excel_mso30_framework_hooked) {
            origIsSubscription = dlsym(RTLD_DEFAULT, func);
        }
        if(!excel_mbuinstrument_framework_hooked) {
            origMbuInAutomatedQTestMode = dlsym(RTLD_DEFAULT, "MbuInAutomatedQTestMode");
            origMbuInAutomatedAssertMode = dlsym(RTLD_DEFAULT, "MbuInAutomatedAssertMode");
            origMbuIsRetailDemoSKU = dlsym(RTLD_DEFAULT, "MbuIsRetailDemoSKU");
        }
        if(origIsSubscription != NULL && !excel_mso30_framework_hooked) {
            struct rebinding rebindings[] = {
                { func, (void *)IsSubscriptionProxy, (void **)&origIsSubscriptionToken }
            };
            rebind_symbols(rebindings, 1);
            excel_mso30_framework_hooked = 1;
        }
        if(origMbuInAutomatedQTestMode != NULL && !excel_mbuinstrument_framework_hooked) {
            struct rebinding rebindings[] = {
                { "MbuInAutomatedQTestMode", (void *)MbuInAutomatedQTestModeProxy, (void **)&origMbuInAutomatedQTestModeToken },
                { "MbuInAutomatedAssertMode", (void *)MbuInAutomatedQTestModeProxy, (void **)&origMbuInAutomatedAssertModeToken },
                { "MbuIsRetailDemoSKU", (void *)MbuInAutomatedQTestModeProxy, (void **)&origMbuIsRetailDemoSKUToken }
            };
            rebind_symbols(rebindings, 1);
            excel_mbuinstrument_framework_hooked = 1;
        }
        usleep(500*10);
    }
    return NULL;
}


void createThread(void *(*start_routine) (void *), void *arg) {
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    int policy;
    pthread_attr_getschedpolicy(&attr, &policy);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    pthread_attr_setinheritsched(&attr, PTHREAD_EXPLICIT_SCHED);
    struct sched_param sched;
    sched.sched_priority = sched_get_priority_max(policy);
    pthread_attr_setschedparam(&attr, &sched);
    pthread_t thread;
    pthread_create(&thread, &attr, start_routine, arg);
    pthread_attr_destroy(&attr);
}

static void Thread(void) {
    static bool is_initialized_bootstrap = false;
    if (is_initialized_bootstrap) {
        return;
    }
    createThread(threadMSO30, NULL);
    is_initialized_bootstrap = true;
}

extern __attribute__((__constructor__)) void _MSInitialize(void) {
    @autoreleasepool {
        Thread();
    }
}