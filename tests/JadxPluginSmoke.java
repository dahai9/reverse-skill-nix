import com.zin.jadxaimcp.server.PluginServer;
import com.zin.jadxaimcp.deps.javalin.Javalin;
import java.lang.reflect.Field;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import org.eclipse.jetty.server.ServerConnector;

public class JadxPluginSmoke {
    public static void main(String[] args) throws Exception {
        PluginServer plugin = new PluginServer(null, 0);
        try {
            plugin.start();
            Field field = PluginServer.class.getDeclaredField("app");
            field.setAccessible(true);
            Javalin app = (Javalin) field.get(plugin);
            ServerConnector connector = (ServerConnector) app.jettyServer().server().getConnectors()[0];
            if (!"127.0.0.1".equals(connector.getHost())) {
                throw new AssertionError("Unexpected bind address: " + connector.getHost());
            }
            URI uri = URI.create("http://127.0.0.1:" + connector.getLocalPort() + "/health");
            var request = HttpRequest.newBuilder(uri).timeout(Duration.ofSeconds(5)).GET().build();
            var response = HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                throw new AssertionError("Health endpoint: " + response.statusCode());
            }
            System.out.println("JADX plugin: loopback bind and HTTP health OK");
        } finally {
            plugin.stop();
        }
    }
}
