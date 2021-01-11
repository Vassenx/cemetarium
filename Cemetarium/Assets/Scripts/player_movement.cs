using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class player_movement : MonoBehaviour
{
    [SerializeField] private float speed;
    [SerializeField] private float jumpForce;
    Rigidbody playerBody;
    Vector3 orientation;
    float jumpLimit = 1f;

    // Start is called before the first frame update
    void Start()
    {
        playerBody = GetComponent<Rigidbody>();
    }

    private void FixedUpdate()
    {
            Walk();
    }


    private bool IsGrounded()
    {
        //Debug.DrawRay(transform.position, Vector3.down * speed, Color.red);
        return Physics.Raycast(transform.position, Vector3.down, jumpLimit);
      
    }

    private void Walk()
    {
        float horizontal = Input.GetAxisRaw("Horizontal");
        float vertical = Input.GetAxisRaw("Vertical");

        Vector3 move = new Vector3(horizontal, 0, vertical) * speed * Time.fixedDeltaTime;

        Vector3 newPosition = playerBody.position + playerBody.transform.TransformDirection(move);
        playerBody.MovePosition(newPosition);
    }


}
