using System.Collections;
using UnityEngine;

public class Flicker : MonoBehaviour
{
    [SerializeField] private Light bulb;

    private (float, float) flickerCooldownRange = (3f, 10f);
    private float timeSinceLastFlicker = 0f;
    private (float, float) flickerSpeedRange = (0.01f, 0.04f);
    private (int,int) flickersInRowRange = (4,10);

    private void Start()
    {
        timeSinceLastFlicker = Time.time;
    }

    private void Update()
    {
        if(Time.time - timeSinceLastFlicker >= Random.Range(flickerCooldownRange.Item1, flickerCooldownRange.Item2))
        {
            StartCoroutine(FlickerLerp());
            timeSinceLastFlicker = Time.time;
        }
    }

    IEnumerator FlickerLerp()
    {
        for (int i = 0; i < Random.Range(flickersInRowRange.Item1, flickersInRowRange.Item2); i++)
        {
            bulb.enabled = false;
            yield return new WaitForSeconds(Random.Range(flickerSpeedRange.Item1, flickerSpeedRange.Item2));
            bulb.enabled = true;
            //I like the look of a longer delay here
            yield return new WaitForSeconds(Random.Range(flickerSpeedRange.Item1 + 0.1f, flickerSpeedRange.Item2 + 0.2f));
        }

        yield return new WaitForEndOfFrame();
    }
}
