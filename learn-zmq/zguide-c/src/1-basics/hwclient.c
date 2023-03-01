//  Hello World client
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <zmq.h>

int main(void) {
  printf("Connecting to hello world server...\n");
  void *context = zmq_ctx_new();
  void *requester = zmq_socket(context, ZMQ_REQ);
  zmq_connect(requester, "tcp://localhost:5555");

  int count;
  for (count = 0; count != 10; count++) {
    char buffer[10];
    printf("Sending Hello %d...\n", count);
    zmq_send(requester, "Hello", 5, 0);
    zmq_recv(requester, buffer, 10, 0);
    printf("Received World %d\n", count);
  }

  zmq_close(requester);
  zmq_ctx_destroy(context);
  return 0;
}
