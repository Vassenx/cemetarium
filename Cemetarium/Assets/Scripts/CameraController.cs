using UnityEngine;

public class CameraController : MonoBehaviour
{
    [SerializeField] private Transform player;

    public float horizontalSpeed = 2.0f;
    public float verticalSpeed = 2.0f;

    private float yaw = 270.0f;
    private float pitch = 0.0f;

    private void Start()
    {
        Cursor.lockState = CursorLockMode.Locked;
        yaw = 270;
    }

    void Update()
    {
            yaw += horizontalSpeed * Input.GetAxis("Mouse X");
            pitch -= verticalSpeed * Input.GetAxis("Mouse Y");

            transform.eulerAngles = new Vector3(pitch, yaw, 0.0f);

            player.eulerAngles = new Vector3(0.0f, yaw, 0.0f);
    }
}