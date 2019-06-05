/*Simple class to keep track of an individual ruler mark */

public class Mark{
  public int songPosTicks;
  public int songPosCM;
  public float screenX;
  
  public Mark(int a, int b, float c){
    songPosTicks = a;
    songPosCM = b;
    screenX = c;
  } 
}