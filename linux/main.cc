#include "my_application.h"
#include <stdlib.h>

int main(int argc, char** argv) {
  // Workaround for WebKit DMA-BUF blank window issue on some Linux GPU drivers.
  // Only sets the variable if not already present in the environment so users
  // who explicitly set it to "0" keep their preference.
  // See: https://github.com/BlueBubblesApp/bluebubbles-app/issues/2942
  setenv("WEBKIT_DISABLE_DMABUF_RENDERER", "1", 0);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
