// KSU-Next/ReSukiSU 风格 hook 的 SukiSU 兼容垫片
// SUSFS 补丁引用这些符号，SukiSU 没有等价实现，这里提供安全空实现
#include <linux/types.h>
#include <linux/fs.h>
#include <linux/jump_label.h>

struct filename;

DEFINE_STATIC_KEY_TRUE(ksu_is_init_rc_hook_enabled);

void ksu_handle_vfs_fstat(int fd, loff_t *kstat_size_ptr) { }

int ksu_handle_stat(int *dfd, struct filename **filename, int *flags) { return 0; }

int ksu_handle_faccessat(int *dfd, struct filename **filename, int *mode, int *__unused_flags) { return 0; }

int ksu_handle_execveat(int *fd, struct filename **filename_ptr, void *argv,
                        void *envp, int *flags) { return 1; }

int ksu_handle_execveat_sucompat(int *fd, struct filename **filename_ptr, void *argv,
                                 void *envp, int *flags) { return 1; }

int ksu_handle_post_execveat_sucompat(int *fd, struct filename **filename_ptr, void *argv,
                                      void *envp, int *flags, int *retval) { return 0; }

void ksu_handle_sys_read(unsigned int fd) { }

int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd, void __user **arg) { return 0; }
