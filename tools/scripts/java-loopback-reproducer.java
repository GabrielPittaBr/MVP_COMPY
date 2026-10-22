import java.net.InetSocketAddress;
import java.nio.channels.Selector;
import java.nio.channels.ServerSocketChannel;
import java.nio.channels.SocketChannel;

public final class JavaLoopbackReproducer {
    public static void main(String[] args) throws Exception {
        try (Selector selector = Selector.open()) {
            System.out.println("Selector.open: PASS");
        }

        try (ServerSocketChannel server = ServerSocketChannel.open()) {
            server.bind(new InetSocketAddress("127.0.0.1", 0));
            try (SocketChannel client = SocketChannel.open()) {
                client.connect(server.getLocalAddress());
                try (SocketChannel accepted = server.accept()) {
                    System.out.println("127.0.0.1 bind/connect/accept: PASS at " + server.getLocalAddress());
                }
            }
        }
    }
}
