#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include <cmath>
#include <cstring>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlView* view;
  FlMethodChannel* namida_channel;
  gulong theme_name_handler;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView *view)
{
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static FlValue* get_system_accent_color(FlView* view) {
  GdkRGBA color;
  GtkStyleContext* context = gtk_widget_get_style_context(GTK_WIDGET(view));
  if (!gtk_style_context_lookup_color(context, "theme_selected_bg_color", &color)) return fl_value_new_null();
  const int64_t alpha = lround(color.alpha * 255);
  const int64_t red = lround(color.red * 255);
  const int64_t green = lround(color.green * 255);
  const int64_t blue = lround(color.blue * 255);
  return fl_value_new_int(alpha << 24 | red << 16 | green << 8 | blue);
}

static void theme_name_changed_cb(GtkSettings* settings, GParamSpec* pspec, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  fl_method_channel_invoke_method(self->namida_channel, "onSystemAccentColorChanged", nullptr, nullptr, nullptr, nullptr);
}

static void set_system_accent_color_listener(MyApplication* self, gboolean enabled) {
  GtkSettings* settings = gtk_settings_get_default();
  if (settings == nullptr) return;
  g_clear_signal_handler(&self->theme_name_handler, settings);
  if (enabled) self->theme_name_handler = g_signal_connect(settings, "notify::gtk-theme-name", G_CALLBACK(theme_name_changed_cb), self);
}

static void namida_channel_method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (strcmp(method, "getSystemAccentColor") == 0) {
    g_autoptr(FlValue) result = get_system_accent_color(self->view);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "setSystemAccentColorListener") == 0) {
    FlValue* enabled = fl_value_lookup_string(fl_method_call_get_args(method_call), "enabled");
    set_system_accent_color_listener(self, enabled != nullptr && fl_value_get_bool(enabled));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(method_call, response, nullptr);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // GError* error = nullptr;
  // GdkPixbuf* icon = gdk_pixbuf_new_from_file(
  //     "data/flutter_assets/assets/namida_icon_mini.png",
  //     &error
  // );
  // if (icon) {
  //     gtk_window_set_icon(window, icon);
  //     g_object_unref(icon);
  // } else if (error) {
  //     g_warning("Failed to load icon: %s", error->message);
  //     g_error_free(error);
  // }

  // Header bar unconditionally (flutter's template skips it on non-GNOME X11):
  // window_manager only undecorates windows that lack one, killing resize edges.
  GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
  gtk_widget_show(GTK_WIDGET(header_bar));
  gtk_header_bar_set_title(header_bar, "namida");
  gtk_header_bar_set_show_close_button(header_bar, TRUE);
  gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  gtk_window_set_title(window, "namida");

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);
  // impeller (gles) costs way more gpu than skia per frame, #1367 #1416
  fl_dart_project_set_enable_impeller(project, FALSE);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000 for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb), self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  self->view = view;
  FlEngine* engine = fl_view_get_engine(view);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->namida_channel = fl_method_channel_new(fl_engine_get_binary_messenger(engine), "namida", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->namida_channel, namida_channel_method_call_cb, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  set_system_accent_color_listener(self, FALSE);
  g_clear_object(&self->namida_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  const gchar* flatpak_id = g_getenv("FLATPAK_ID");
  const gchar* application_id = flatpak_id != nullptr ? flatpak_id : APPLICATION_ID;
  g_set_prgname(application_id);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", application_id,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
