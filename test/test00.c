int streamDefRecord(sdf,dsf,sdf,sdf,)
{
  return 1;
}
int streamWriteRecord(sdf,dsf,sdf,sdf,)
{
  return 1;
}

int streamID(a,b,r,e)
{
  return 1;
}
void *Copy(void *argument)
{
  int COPY, SELALL, SZIP;
  int operatorID;
  int streamID, streamID2 = CDI_UNDEFID;
  int nrecs;
  int tsID1, tsID2, recID, varID, levelID;
  while ( (nrecs = streamInqTimestep(streamID, tsID1)) )
  {
    taxisCopyTimestep(taxisID2, taxisID1);

    streamDefTimestep(streamID2, tsID2);

    for ( recID = 0; recID < nrecs; recID++ )
    { 
      streamInqRecord(streamID, &varID, &levelID);
      streamDefRecord(streamID2,  varID,  levelID);
      streamCopyRecord(streamID2, streamID);
      if ( cdoParIO )
      {
	parIO.recID = recID; parIO.nrecs = nrecs;
	parReadRecord(streamID, &varID, &levelID, array, &nmiss, &parIO);
	//  fprintf(stderr, "in2 streamID %d varID %d levelID %d\n", streamID(), varID, levelID);
	printf("sdfsdf streamID()");
      }
      else
      {
	streamInqRecord(streamID, &varID, &levelID);
	streamReadRecord(streamID, array, &nmiss);
      }
      /*
	 if ( cdoParIO )
	 fprintf(stderr, "out1 %d %d %d\n", streamID2,  varID,  levelID);
	 */
      streamDefRecord(streamID2,  varID,  levelID);
      streamWriteRecord(streamID2, array, nmiss);
      /*
	 if ( cdoParIO )
	 fprintf(stderr, "out2 %d %d %d\n", streamID2,  varID,  levelID);
	 */
    }
  }
  return (0);
}
